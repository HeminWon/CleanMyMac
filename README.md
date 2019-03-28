# CleanMyMac

使用脚本清理mac日常开发工作产生的垃圾文件,避免因长期的使用导致过多垃圾文件堆积。

### 使用方法 <font size="2"> 终端执行 </font></span>

```bash
curl https://raw.githubusercontent.com/HeminWon/CleanMyMac/develop/cleanmymac.sh | sh
```

### 功能
- 清除XCode编译文件Derived Data 和 Archives；
- 清理brew安装的所有的过时软件；
- 清除所有已安装的老版本gem包；
- 支持在清除之前先升级brew及gem，若要升级请点击YES。
![update](https://github.com/HeminWon/CleanMyMac/blob/develop/rsc/update.png)
