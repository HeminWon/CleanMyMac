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

# 显示 macOS 系统通知
# 参数1: 通知内容描述
# 参数2: 通知标题
displayNotification() {
    local description="${1}"
    local title="${2}"
    echo "$description - $title"
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
        result=$(awk "BEGIN {printf \"%.2fKB\", $bytes/1024}")
    elif [ "$bytes" -lt $((1024 * 1024 * 1024)) ]; then
        result=$(awk "BEGIN {printf \"%.2fMB\", $bytes/1024/1024}")
    else
        result=$(awk "BEGIN {printf \"%.2fGB\", $bytes/1024/1024/1024}")
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

# 清理 Xcode 相关文件和缓存
clearXcode() {
    echo "Cleaning Xcode..."

    # 删除不可用的模拟器
    xcrun simctl delete unavailable 2>/dev/null || echo "  Skip: No unavailable simulators"

    # 清理 DerivedData（编译产生的中间文件）
    if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
        find ~/Library/Developer/Xcode/DerivedData -mindepth 1 -delete 2>/dev/null
        echo "  Cleaned DerivedData"
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
            echo "  Warning: Skipped system logs cleaning (requires admin privileges or error occurred)"
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

# 显示确认对话框
# 参数1: 操作动作（如 "update"、"clean"）
# 参数2: 操作对象（如 "brew"、"xcode"）
displayDialog() {
    local action="${1}"
    local target="${2}"
    local question="Do you wish to ${action} ${target}?"

    osascript <<EOF
    display dialog "$question" buttons {"Yes", "No"} default button "No"
EOF
}

# 判断用户是否选择继续操作
# 参数1: 操作动作
# 参数2: 操作对象
# 返回: 0=继续, 1=跳过
shouldProceed() {
    local action="${1}"
    local name="${2}"
    local response

    response=$(displayDialog "$action" "$name")
    [[ "$response" == "button returned:Yes" ]]
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

    echo ""

    # 软件更新
    echo "========================================="
    echo "  Step 1: Software Updates"
    echo "========================================="

    # 更新 Homebrew
    if $brew_available; then
        if shouldProceed "update" "Homebrew"; then
            updateBrew
        else
            echo "Skipped Homebrew update"
        fi
    fi

    # 更新 Mac App Store 应用
    if $mas_available; then
        if shouldProceed "update" "Mac App Store apps"; then
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
    echo "Available space before cleaning: $(awk "BEGIN {printf \"%.2fGB\", $oldAvailable/1024/1024}")"
    echo ""

    # 清理 CocoaPods 缓存
    if $pod_available; then
        if shouldProceed "clean" "CocoaPods cache"; then
            clearCocoapods
        else
            echo "Skipped CocoaPods cleaning"
        fi
    fi

    # 清理 Xcode
    if shouldProceed "clean" "Xcode cache"; then
        clearXcode
    else
        echo "Skipped Xcode cleaning"
    fi

    # 清理系统缓存
    if shouldProceed "clean" "system cache"; then
        clearCache
    else
        echo "Skipped system cache cleaning"
    fi

    # 清理日志文件
    if shouldProceed "clean" "log files"; then
        clearLogs
    else
        echo "Skipped log cleaning"
    fi

    # 清空废纸篓
    if shouldProceed "empty" "Trash"; then
        clearTrash
    else
        echo "Skipped emptying Trash"
    fi

    # 清理 Homebrew 缓存
    if $brew_available; then
        if shouldProceed "clean" "Homebrew cache"; then
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
        if shouldProceed "clean" "Ruby gems cache"; then
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

    # 获取清理后的可用空间（单位：KB）
    newAvailable=$(available)
    echo "Available space after cleaning: $(awk "BEGIN {printf \"%.2fGB\", $newAvailable/1024/1024}")"

    # 计算释放的空间（KB 转换为字节）
    freedSpace=$((newAvailable - oldAvailable))
    freedBytes=$((freedSpace * 1024))

    # 显示释放空间的通知
    if [ "$freedBytes" -gt 0 ]; then
        bytesToHumanReadable "$freedBytes"
        echo "Successfully freed: $(awk "BEGIN {printf \"%.2fGB\", $freedBytes/1024/1024/1024}")"
    else
        echo "No space freed (disk might be full or cleaning items were empty)"
    fi

    echo ""
    echo "All operations completed!"
}

# 脚本入口点：执行主函数
main
