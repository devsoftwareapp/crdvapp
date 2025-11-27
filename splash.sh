#!/bin/bash
# splash.sh - Tek PNG ile Android splash oluşturma (önce temizler)

# Kaynak PNG
SOURCE="res/screen/android/splash.png"

# Android res klasörü
RES_DIR="platforms/android/app/src/main/res"

# Drawable klasörleri ve boyut ölçekleri
declare -A DENSITIES=(
  ["drawable-ldpi"]=36
  ["drawable-mdpi"]=48
  ["drawable-hdpi"]=72
  ["drawable-xhdpi"]=96
  ["drawable-xxhdpi"]=144
  ["drawable-xxxhdpi"]=192
)

# Önce eski splash.png dosyalarını sil
for DIR in "${!DENSITIES[@]}"; do
  TARGET_DIR="$RES_DIR/$DIR"
  if [ -d "$TARGET_DIR" ]; then
    rm -f "$TARGET_DIR/splash.png"
    echo "Removed old $TARGET_DIR/splash.png"
  fi
done

# Klasörleri oluştur ve resize yap
for DIR in "${!DENSITIES[@]}"; do
  mkdir -p "$RES_DIR/$DIR"
  SIZE=${DENSITIES[$DIR]}
  convert "$SOURCE" -resize ${SIZE}x${SIZE} "$RES_DIR/$DIR/splash.png"
  echo "Created $RES_DIR/$DIR/splash.png ($SIZE x $SIZE)"
done

# Önceki splashscreen.xml varsa sil
XML_PATH="res/screen/android/splashscreen.xml"
if [ -f "$XML_PATH" ]; then
  rm "$XML_PATH"
  echo "Removed old $XML_PATH"
fi

# splashscreen.xml oluştur
mkdir -p "$(dirname "$XML_PATH")"
cat > "$XML_PATH" <<EOL
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white"/>
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/splash"/>
    </item>
</layer-list>
EOL

echo "splashscreen.xml created at $XML_PATH"
