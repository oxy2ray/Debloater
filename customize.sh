if ! $BOOTMODE; then
    ui_print "*********************************************************"
    ui_print "Warn: Please DO NOT install via recovery,"
    ui_print "Warn: Module require Package Manager to work,"
    ui_print "Warn: Install it through your module manager. Exiting."
    abort    "*********************************************************"
fi

pkg_list=$MODPATH/pkglist.prop
external_list="/data/adb/modules/Debloater/pkglist.prop"
not_system="^/(product|vendor|odm|system_ext)"

if [ ! -f "$external_list" ]; then
  ui_print " - 首次安装"
else
  ui_print " - 找到了已安装模块"
  grep -E '^#|^$' "$pkg_list"
  cat "$pkg_list" "$external_list" | grep -vE '^#|^$' | sort | uniq > "$TMPDIR/pkglist.tmp"
    if mv "$TMPDIR/pkglist.tmp" "$pkg_list"; then
     ui_print " - 已合并外部包列表：$external_list"
     ui_print " - 当前有效包的数量：$(grep -vcE '^#|^$' "$pkg_list")"
    else
        ui_print " - 错误: 无法与已存在的模块合并"
        ui_print " - 建议: 尝试卸载已安装的旧模块。"
        abort
    fi
fi
grep -v '^#' "$pkg_list" | while read -r pkg_name; do
  if ! pm list packages "$pkg_name" | grep -q "^package:${pkg_name}$"; then
    ui_print " - 找不到: ($pkg_name), 跳过。"
    continue
  else
    apk_path=$(pm path "$pkg_name" | sed 's/package://g')
  fi
  while : ; do
    if [ -z "$apk_path" ]; then
      ui_print " "
      ui_print " - 未获取到路径: ($pkg_name), 或许不存在, 跳过。"
      break
    elif ! [[ "$apk_path" =~ ^/.*\.apk$ ]]; then
      ui_print " "
      ui_print " - 不期望的路径: ($apk_path), 跳过。"
      break
    elif [[ "$apk_path" =~ ^/data/app/ ]]; then
      ui_print " "
      ui_print " - 应用: $pkg_name 出现在 /data 分区。正在卸载。"
      pm uninstall "$pkg_name" >/dev/null 2>&1
      apk_path=$(pm path "$pkg_name" 2>/dev/null | sed 's/package://g')
      continue
    elif echo "$apk_path" | grep -Eq "$not_system"; then
      partition=$(echo "$apk_path" | sed -nE "s|^/(product|vendor|odm|system_ext)/.*|\1|p")
      sub_path=$(echo "$apk_path" | sed -E "s|^/$partition/?||")
      apk_path="/system/$partition$sub_path"
      break
    else
      break
    fi
  done
  
  pkg_path="$(dirname "$apk_path")"
  ui_print " "
  ui_print " - 清除数据: ($pkg_name) $apk_path" && pm clear $pkg_name
  ui_print " - 正在移除: ($pkg_name) $apk_path"
  if ! mkdir -p "$(dirname "${MODPATH}${pkg_path}")"; then
    ui_print " - 致命错误: 无法创建路径"
    ui_print " - 跳过"
  else
    ui_print " - 创建父级目录: $(dirname "${MODPATH}${pkg_path}")"
  fi
  if ! mknod "${MODPATH}${pkg_path}" c 0 0; then
    ui_print " - 致命错误: 无法创建字符设备"
    ui_print " - 跳过"
  else
    ui_print " - 创建字符设备: ${MODPATH}${pkg_path}"
  fi
  ui_print " "
done
ui_print " "
ui_print " - 结束"