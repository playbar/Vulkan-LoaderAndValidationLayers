#!/bin/bash

if [ -z "${ANDROID_SDK_HOME}" ];
then echo "Please set ANDROID_SDK_HOME, exiting"; exit 1;
else echo "ANDROID_SDK_HOME is ${ANDROID_SDK_HOME}";
fi

if [ -z "${ANDROID_NDK_HOME}" ];
then echo "Please set ANDROID_NDK_HOME, exiting"; exit 1;
else echo "ANDROID_NDK_HOME is ${ANDROID_NDK_HOME}";
fi

if [[ $(uname) == "Linux" ]]; then
    cores=$(nproc)
elif [[ $(uname) == "Darwin" ]]; then
    cores=$(sysctl -n hw.ncpu)
fi

set -v

#
# clean up
#
rm -r bin/ libs/ obj/ generated/ ../demos/android/cube-with-layers/bin/ ../demos/android/cube/bin/ ../demos/android/obj/
set -ev

#
# build layers
#
LAYER_BUILD_DIR=$PWD
echo LAYER_BUILD_DIR=$LAYER_BUILD_DIR
./update_external_sources_android.sh
./android-generate.sh
ndk-build -j $cores

# NOTE: These should be refactored into functions, but this series works

#
# build VulkanLayerValidationTests APK
#
mkdir -p bin/libs/lib
# These soft links create the directory structure required to package APK with aapt
for filename in $(ls $LAYER_BUILD_DIR/libs); do
    ln -sf $LAYER_BUILD_DIR/libs/$filename $LAYER_BUILD_DIR/bin/libs/lib/$filename
done;
aapt package -f -M AndroidManifest.xml -I "$ANDROID_SDK_HOME/platforms/android-23/android.jar" -S res -F bin/VulkanLayerValidationTests-unaligned.apk bin/libs
# update this logic to detect if key is already there.  If so, use it, otherwise create it.
jarsigner -verbose -keystore ~/.android/debug.keystore -storepass android -keypass android  bin/VulkanLayerValidationTests-unaligned.apk androiddebugkey
zipalign -f 4 bin/VulkanLayerValidationTests-unaligned.apk bin/VulkanLayerValidationTests.apk

#
# build cube APK
#
(
pushd ../demos/android
CUBE_BUILD_DIR=$PWD
CUBE_OUT_DIR=$CUBE_BUILD_DIR/cube
CUBE_LIB_DIR=$CUBE_OUT_DIR/bin/libs/lib
ndk-build -j $cores
cd cube
mkdir -p bin/libs/lib
# These soft links create the directory structure required to package APK with aapt
for filename in $(ls $CUBE_BUILD_DIR/libs); do
    ln -sf $CUBE_BUILD_DIR/libs/$filename $CUBE_LIB_DIR/$filename;
done;
cd $CUBE_OUT_DIR
aapt package -f -M AndroidManifest.xml -I "$ANDROID_SDK_HOME/platforms/android-23/android.jar" -S res -F bin/cube-unaligned.apk bin/libs
jarsigner -verbose -keystore ~/.android/debug.keystore -storepass android -keypass android  bin/cube-unaligned.apk androiddebugkey
zipalign -f 4 bin/cube-unaligned.apk bin/cube.apk
popd
)

#
# build cube-with-layers APK
#
(
pushd ../demos/android
CUBE_BUILD_DIR=$PWD
CUBE_OUT_DIR=$CUBE_BUILD_DIR/cube-with-layers
CUBE_LIB_DIR=$CUBE_OUT_DIR/bin/libs/lib
ndk-build -j $cores
mkdir -p $CUBE_LIB_DIR
# These loops pull together directory structure required to package APK with aapt
for archname in $(ls $CUBE_BUILD_DIR/libs); do
    mkdir -p $CUBE_LIB_DIR/$archname;
    for libname in $(ls $CUBE_BUILD_DIR/libs/$archname); do
        ln -sf $CUBE_BUILD_DIR/libs/$archname/$libname $CUBE_LIB_DIR/$archname/$libname;
    done;
    for layername in $(ls $LAYER_BUILD_DIR/libs/$archname); do
        ln -sf $LAYER_BUILD_DIR/libs/$archname/$layername $CUBE_LIB_DIR/$archname/$layername;
    done;
done;
cd $CUBE_OUT_DIR
aapt package -f -M AndroidManifest.xml -I "$ANDROID_SDK_HOME/platforms/android-23/android.jar" -S res -F bin/cube-with-layers-unaligned.apk bin/libs
jarsigner -verbose -keystore ~/.android/debug.keystore -storepass android -keypass android  bin/cube-with-layers-unaligned.apk androiddebugkey
zipalign -f 4 bin/cube-with-layers-unaligned.apk bin/cube-with-layers.apk
popd
)

#
# build Smoke with layers
#
# TODO

echo Builds succeeded
exit 0
