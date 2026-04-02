#!/usr/bin/env bash

# CleanMyMac - macOS 系统清理工具
# 用于清理缓存、日志和更新软件
# https://brew.sh/
# https://github.com/buo/homebrew-cask-upgrade

# 遇到错误时退出脚本
set -e
# 取消下面注释可以显示执行的每一条命令（调试用）
# set -x

# 检查命令是否存在
checkCommand() {
    local cmd="${1}"
    local name="${2}"
    if ! type "$cmd" >/dev/null 2>&1; then
        echo "Warning: $name ($cmd) is not installed, related features will be skipped"
        return 1
    fi
    return 0
}

# 显示 macOS 系统通知（仅弹窗，不重复打印到终端）
# 参数1: 通知内容描述
# 参数2: 通知标题
displayNotification() {
    local description="${1}"
    local title="${2}"
    osascript <<EOF
    display notification "$description" with title "$title"
EOF
}

# 将字节数转换为人类可读格式（KB, MB, GB 等）
# 参数1: 字节数
bytesToHumanReadable() {
    local bytes="${1}"
    local result

    # 使用 awk 进行转换（macOS 原生支持，不依赖 GNU coreutils）
    if [ "$bytes" -lt 1024 ]; then
        result="${bytes}B"
    elif [ "$bytes" -lt $((1024 * 1024)) ]; then
        result=$(awk -v b="$bytes" 'BEGIN {printf "%.2fKB", b/1024}')
    elif [ "$bytes" -lt $((1024 * 1024 * 1024)) ]; then
        result=$(awk -v b="$bytes" 'BEGIN {printf "%.2fMB", b/1024/1024}')
    else
        result=$(awk -v b="$bytes" 'BEGIN {printf "%.2fGB", b/1024/1024/1024}')
    fi

    local message="$result of space was cleaned up :3"
    local noti="CleanMyMac"
    displayNotification "$message" "$noti"
}

# 获取根目录可用空间（单位：KB）
available() {
    df -k / | awk 'NR==2 {print $4}'
}

# 更新 Homebrew 及其管理的软件包
updateBrew() {
    echo "Updating Homebrew..."

    # 检测当前系统架构（支持 Intel 和 Apple Silicon）
    local arch_cmd=""
    if [ "$(uname -m)" = "arm64" ]; then
        arch_cmd="arch -arm64"
    fi

    # 更新 Homebrew 本身
    $arch_cmd brew update &&
        # 更新所有 formula 软件包
        $arch_cmd brew upgrade &&
        # 更新所有 cask 应用（--greedy 包括自动更新的应用）
        $arch_cmd brew upgrade --cask --greedy
}

# 更新 Mac App Store 应用
updateMas() {
    echo "Updating Mac App Store apps..."
    mas upgrade
}

# 清理 CocoaPods 缓存
clearCocoapods() {
    echo "Cleaning CocoaPods cache..."
    pod cache clean --all
}

# 清理 Xcode 模拟器（不可用设备 + 老版本运行时）
# 先列出即将清理项，再询问确认，确认后才执行删除
clearXcodeSimulators() {
    echo "Checking Xcode simulators (unavailable devices + old runtimes)..."

    local unavailable_output
    unavailable_output=$(xcrun simctl list devices unavailable 2>/dev/null || true)
    local has_unavailable=0
    if echo "$unavailable_output" | grep -qE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'; then
        has_unavailable=1
    fi

    # 老版本运行时：按平台+版本号排序，只保留每类最新版本号一条，其余待删
    local to_delete=""
    if xcrun simctl runtime list &>/dev/null; then
        local keep_per_platform=1
        local full_list
        full_list=$(xcrun simctl runtime list 2>/dev/null | awk '
            /^(iOS|watchOS|tvOS) [0-9]/ { print $1, $2, $5 }
        ' | sort -k1,1 -k2,2V)
        to_delete=$(echo "$full_list" | awk -v keep="$keep_per_platform" '
            { key=$1; count[key]++; line[key,count[key]]=$0 }
            END {
                for (p in count) {
                    for (i=1; i<=count[p]; i++) {
                        if (i <= count[p] - keep) print line[p,i]
                    }
                }
            }
        ')
    fi

    # 无任何可清理项时直接退出
    if [ "$has_unavailable" -eq 0 ] && [ -z "$to_delete" ]; then
        echo "  Nothing to clean (no unavailable devices, no old runtimes)"
        return
    fi

    # 先输出即将清理的内容，再确认
    echo "  The following will be removed:"
    if [ "$has_unavailable" -eq 1 ]; then
        echo "  Unavailable devices (invalid after Xcode upgrade):"
        echo "$unavailable_output" | sed 's/^/    /'
    fi
    if [ -n "$to_delete" ]; then
        echo "  Old runtimes (keeping latest per platform):"
        echo "$to_delete" | while read -r platform version _uuid; do
            echo "    - $platform $version"
        done
    fi
    echo ""
    echo -n "  Proceed to delete the above? [y/N] "
    read -r answer </dev/tty
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "  Skipped"
        return
    fi

    echo "Cleaning Xcode simulators..."
    if [ "$has_unavailable" -eq 1 ]; then
        xcrun simctl delete unavailable 2>/dev/null || true
        echo "  Removed unavailable devices"
    fi
    if [ -n "$to_delete" ]; then
        echo "$to_delete" | while read -r platform version uuid; do
            echo "    Deleting: $platform $version"
            xcrun simctl runtime delete "$uuid" 2>/dev/null || true
        done
        echo "  Removed old simulator runtimes"
    fi
}

# 清理 Xcode 缓存与构建产物（DerivedData、Archives、设备支持等）
clearXcodeCaches() {
    echo "Cleaning Xcode caches & build artifacts..."

    # 清理 DerivedData（构建产物 + 索引数据，含编译中间文件、代码索引、Module 缓存等，体积常达数十 GB）
    if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
        find ~/Library/Developer/Xcode/DerivedData -mindepth 1 -delete 2>/dev/null
        echo "  Cleaned DerivedData (build + index)"
    fi

    # 清理 Xcode 应用缓存（预览、符号等，可安全重建）
    if [ -d ~/Library/Caches/com.apple.dt.Xcode ]; then
        find ~/Library/Caches/com.apple.dt.Xcode -mindepth 1 -delete 2>/dev/null
        echo "  Cleaned Xcode app cache"
    fi

    # 清理文档索引（Documentation 索引，下次打开文档会重建）
    if [ -d ~/Library/Developer/Xcode/UserData/DocumentationIndex ]; then
        rm -rf ~/Library/Developer/Xcode/UserData/DocumentationIndex 2>/dev/null
        echo "  Cleaned DocumentationIndex"
    fi

    # 清理编辑器交互历史缓存（跳转/补全等历史，可安全删除）
    if [ -d ~/Library/Developer/Xcode/UserData/IDEEditorInteractivityHistory ]; then
        find ~/Library/Developer/Xcode/UserData/IDEEditorInteractivityHistory -mindepth 1 -delete 2>/dev/null
        echo "  Cleaned IDEEditorInteractivityHistory"
    fi

    # 清理 Archives（归档文件）
    if [ -d ~/Library/Developer/Xcode/Archives ]; then
        find ~/Library/Developer/Xcode/Archives -mindepth 1 -delete 2>/dev/null
        echo "  Cleaned Archives"
    fi

    # 清理 Products（产品文件）
    if [ -d ~/Library/Developer/Xcode/Products ]; then
        find ~/Library/Developer/Xcode/Products -mindepth 1 -delete 2>/dev/null
        echo "  Cleaned Products"
    fi

    # 清理旧的 iOS 设备支持文件（保留最新版本）
    local device_support_dir=~/Library/Developer/Xcode/iOS\ DeviceSupport
    if [ -d "$device_support_dir" ]; then
        cd "$device_support_dir" || return

        # 获取最新版本的设备支持文件
        local latest_file
        latest_file=$(ls 2>/dev/null | sort -rV | head -n1)

        # 只有当找到文件时才删除旧版本
        if [ -n "$latest_file" ]; then
            echo "  Keeping latest device support: $latest_file"
            # 删除除最新版本外的所有旧版本（使用更安全的方法）
            for item in *; do
                if [ "$item" != "$latest_file" ]; then
                    rm -rf "$item" 2>/dev/null
                fi
            done
            echo "  Cleaned old iOS DeviceSupport"
        else
            echo "  Skip: iOS DeviceSupport directory is empty"
        fi

        # 返回原目录
        cd - >/dev/null || return
    fi
}

# 清理系统和应用缓存
clearCache() {
    echo "Cleaning cache directories..."

    # 清理用户缓存
    if [ -d ~/Library/Caches ]; then
        # 使用 find 命令，更可靠地删除缓存文件
        find ~/Library/Caches -type f -delete 2>/dev/null
        find ~/Library/Caches -type d -empty -delete 2>/dev/null
        echo "  Cleaned user caches"
    fi

    # 清理应用支持文件中的缓存
    if [ -d ~/Library/Application\ Support ]; then
        find ~/Library/Application\ Support -type d -name "Cache" -exec rm -rf {} + 2>/dev/null
        echo "  Cleaned application caches"
    fi

    # 清理容器应用的缓存
    if [ -d ~/Library/Containers ]; then
        find ~/Library/Containers -type d -path "*/Data/Library/Caches/*" -delete 2>/dev/null
        echo "  Cleaned container caches"
    fi

    # 清理 iOS 设备日志
    if [ -d ~/Library/Developer/Xcode/iOS\ Device\ Logs ]; then
        find ~/Library/Developer/Xcode/iOS\ Device\ Logs -type f -delete 2>/dev/null
        find ~/Library/Developer/Xcode/iOS\ Device\ Logs -type d -empty -delete 2>/dev/null
        echo "  Cleaned iOS device logs"
    fi

    # 清理 Xcode DerivedData（如果之前没清理过）
    if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
        find ~/Library/Developer/Xcode/DerivedData -type f -delete 2>/dev/null
        find ~/Library/Developer/Xcode/DerivedData -type d -empty -delete 2>/dev/null
        echo "  Cleaned Xcode DerivedData"
    fi

    echo "Cache cleaning completed"
}

# 清理应用日志文件
clearLogs() {
    echo "Cleaning application logs..."

    # 清理用户日志（不需要 sudo）
    if [ -d ~/Library/Logs ]; then
        # 使用 find 命令递归删除所有文件，更可靠
        # -type f 只删除文件，-type d 删除空目录
        find ~/Library/Logs -type f -delete 2>/dev/null
        find ~/Library/Logs -type d -empty -delete 2>/dev/null
        echo "  Cleaned user logs"
    fi

    # 清理系统日志（需要 sudo 权限）
    echo "  Cleaning system logs (requires admin privileges)..."
    if sudo -n true 2>/dev/null; then
        # 已有 sudo 权限
        sudo find /Library/Logs -type f -delete 2>/dev/null
        sudo find /Library/Logs -type d -empty -delete 2>/dev/null
        echo "  Cleaned system logs"
    else
        # 需要输入密码
        echo "  Please enter admin password to clean system logs:"
        if sudo find /Library/Logs -type f -delete 2>/dev/null && \
           sudo find /Library/Logs -type d -empty -delete 2>/dev/null; then
            echo "  Cleaned system logs"
        else
            echo "  Warning: Skipped system logs (admin required or error occurred)"
        fi
    fi

    echo "Application logs cleaning completed"
}

# 清空废纸篓
clearTrash() {
    echo "Emptying Trash..."
    if [ -d ~/.Trash ]; then
        # 使用 find 命令清空，包括隐藏文件
        # -mindepth 1 确保不删除 .Trash 目录本身
        find ~/.Trash -mindepth 1 -delete 2>/dev/null
        echo "Trash emptied"
    else
        echo "Trash directory does not exist"
    fi
}

# 终端内 y/n 确认（不弹窗）
# 参数1: 提示文案，如 "Update Homebrew? [y/N] "
# 返回: 0=选 y 继续, 非0=跳过
confirm() {
    local prompt="${1}"
    echo -n "  $prompt"
    read -r answer </dev/tty
    [[ "$answer" =~ ^[Yy]$ ]]
}

# 主函数入口
main() {
    echo "========================================="
    echo "  CleanMyMac - Startup"
    echo "========================================="
    echo ""

    # 依赖检查
    echo "Checking dependencies..."

    local brew_available=false
    local mas_available=false
    local pod_available=false

    if checkCommand "brew" "Homebrew"; then
        brew_available=true
    fi

    if checkCommand "mas" "Mac App Store CLI"; then
        mas_available=true
    fi

    if checkCommand "pod" "CocoaPods"; then
        pod_available=true
    fi

    echo "  Detected: Homebrew $([ "$brew_available" = true ] && echo '✓' || echo '–'), mas $([ "$mas_available" = true ] && echo '✓' || echo '–'), CocoaPods $([ "$pod_available" = true ] && echo '✓' || echo '–')"
    echo ""

    # 软件更新
    echo "========================================="
    echo "  Step 1: Software Updates"
    echo "========================================="

    # 更新 Homebrew
    if $brew_available; then
        if confirm "Update Homebrew? [y/N] "; then
            updateBrew
        else
            echo "Skipped Homebrew update"
        fi
    fi

    # 更新 Mac App Store 应用
    if $mas_available; then
        if confirm "Update Mac App Store apps? [y/N] "; then
            updateMas
        else
            echo "Skipped Mac App Store update"
        fi
    fi

    echo ""

    # 清理操作
    echo "========================================="
    echo "  Step 2: Cleaning Caches and Logs"
    echo "========================================="

    # 记录清理前的可用空间（单位：KB）
    oldAvailable=$(available)
    echo "Available space before cleaning: $(awk -v k="$oldAvailable" 'BEGIN {printf "%.2f", k/1024/1024}') GB"
    echo ""

    # 清理 CocoaPods 缓存
    if $pod_available; then
        if confirm "Clean CocoaPods cache? [y/N] "; then
            clearCocoapods
        else
            echo "Skipped CocoaPods cleaning"
        fi
    fi

    # 清理 Xcode 缓存与构建产物（DerivedData、Archives 等）
    if confirm "Clean Xcode caches & build artifacts (DerivedData, Archives, etc.)? [y/N] "; then
        clearXcodeCaches
    else
        echo "Skipped Xcode caches cleaning"
    fi

    # 清理 Xcode 模拟器（先检查并列出即将清理项，再询问确认）
    clearXcodeSimulators

    # 清理系统缓存
    if confirm "Clean system cache? [y/N] "; then
        clearCache
    else
        echo "Skipped system cache cleaning"
    fi

    # 清理日志文件
    if confirm "Clean log files? [y/N] "; then
        clearLogs
    else
        echo "Skipped log cleaning"
    fi

    # 清空废纸篓
    if confirm "Empty Trash? [y/N] "; then
        clearTrash
    else
        echo "Skipped emptying Trash"
    fi

    # 清理 Homebrew 缓存
    if $brew_available; then
        if confirm "Clean Homebrew cache? [y/N] "; then
            echo "Cleaning Homebrew..."

            # 检测系统架构
            local arch_cmd=""
            if [ "$(uname -m)" = "arm64" ]; then
                arch_cmd="arch -arm64"
            fi

            $arch_cmd brew cleanup
            echo "Homebrew cleaning completed"
        else
            echo "Skipped Homebrew cleaning"
        fi
    fi

    # 清理 Ruby gems
    if checkCommand "gem" "RubyGems"; then
        if confirm "Clean Ruby gems cache? [y/N] "; then
            echo "Cleaning Ruby gems..."
            gem cleanup
            echo "Ruby gems cleaning completed"
        else
            echo "Skipped Ruby gems cleaning"
        fi
    fi

    echo ""

    # 计算清理效果
    echo "========================================="
    echo "  Cleaning Completed!"
    echo "========================================="

    newAvailable=$(available)
    freedSpace=$((newAvailable - oldAvailable))
    freedBytes=$((freedSpace * 1024))

    echo "Available space after cleaning: $(awk -v k="$newAvailable" 'BEGIN {printf "%.2f", k/1024/1024}') GB"
    if [ "$freedBytes" -gt 0 ]; then
        echo "Freed: $(awk -v b="$freedBytes" 'BEGIN {printf "%.2f", b/1024/1024/1024}') GB"
        bytesToHumanReadable "$freedBytes"
    else
        echo "Freed: 0 GB (no cleanup ran or disk full)"
    fi

    echo ""
    echo "All operations completed!"
}

# 脚本入口点：执行主函数
main
