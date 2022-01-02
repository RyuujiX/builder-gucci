#! /bin/bash

getInfo() {
    echo -e "\e[1;32m$*\e[0m"
}
getInfoErr() {
    echo -e "\e[1;41m$*\e[0m"
}
update_file() {
    if [ ! -z "$1" ] && [ ! -z "$2" ] && [ ! -z "$3" ];then
        GetValue="$(cat $3 | grep "$1")"
        GetPath=${3/"."/""}
        ValOri="$(echo "$GetValue" | awk -F '\\=' '{print $2}')"
        UpdateTo="$(echo "$2" | awk -F '\\=' '{print $2}')"
        [ "$ValOri" != "$UpdateTo" ] && \
        sed -i "s/$1.*/$2/g" "$3"
        [ ! -z "$(git status | grep "modified" )" ] && \
        git add "$3" && \
        git commit -s -m "$GetPath: '$GetValue' update to '$2'"
    fi
}

## Commands
# Send Info
tg_send_info(){
    if [ ! -z "$2" ];then
        curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$2" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
    else
        curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$InfoChatID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
    fi
}

# Send Sticker
tg_send_sticker() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendSticker" \
        -d sticker="$1" \
        -d chat_id="$InfoChatID"
}

# Send Kernel Files
tg_send_files(){
    KernelFiles="$(pwd)/$ZipName"
	MD5CHECK=$(md5sum "$KernelFiles" | cut -d' ' -f1)
	SID="CAACAgUAAxkBAAIb0mBy2DMFsj1kyc5H-sxMRU4uGq4XAAJxAwACckHJVoQTT9R9yDxQHgQ"
    MSG="✅ <b>Kernel Compiled Succesfully</b> 
- <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s) </code>

<b>Compiled at</b>
- <code>$(date)</code>

<b>MD5 Checksum</b>
- <code>$MD5CHECK</code>

<b>Zip Name</b> 
- <code>$ZipName</code>"
	
        getInfo ">> Sending "$ZipName" . . . . <<"
		curl --progress-bar -F document=@"$KernelFiles" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
        -F chat_id="$FileChatID"  \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$MSG"
		
			tg_send_info "$MSG"
			tg_send_sticker "$SID"
			getInfo ">> File Sent ! <<"
		
    # remove files after send done
    rm -rf $KernelFiles
}

# Get Kernel Info
GetKernelInfo(){
	KName=$(cat "$(pwd)/$DEFCONFIGPATH/$DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )
	KVer=$(make kernelversion)
}

# CompileKernel
CompileKernel(){
	getInfo ">> Compiling kernel . . . . <<"
    [[ "$(pwd)" != "${kernelDir}" ]] && cd "${kernelDir}"
	GetKernelInfo
	export KBUILD_BUILD_HOST="KereAktif"
	export USE_CCACHE=1
	export ARCH=arm
	export SUBARCH=arm
	export CROSS_COMPILE=$gcc32Dir/bin/$for32-
    BUILD_START=$(date +"%s")
		if [ ! -z "${CIRCLE_BRANCH}" ];then
            BuildNumber="${CIRCLE_BUILD_NUM}"
            ProgLink="${CIRCLE_BUILD_URL}"
        elif [ ! -z "${DRONE_BRANCH}" ];then
            BuildNumber="${DRONE_BUILD_NUMBER}"
            ProgLink="https://cloud.drone.io/${DRONE_REPO}/${DRONE_BUILD_NUMBER}/1/2"
		elif [ ! -z "${GITHUB_REF}" ];then
            BuildNumber="${GITHUB_RUN_NUMBER}"
            ProgLink="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
        fi
		
		MessageTag="#PRIVATE #HMP"
        MSG="<b>🔨 Compiling Kernel....</b>%0A<b>Device: Redmi Note 1S</b>%0A<b>Codename: gucci</b>%0A<b>Compile Date: $GetCBD </b>%0A<b>Kernel Name: $KName</b>%0A<b>Kernel Version: $KVer</b>%0A<b>Total Cores: $TotalCores</b>%0A<b>Last Commit-Message: $HeadCommitMsg </b>%0A<b>Compile Link Progress:</b><a href='$ProgLink'> Check Here </a>%0A<b>Compiler Info: </b>%0A<code>xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</code>%0A<code>- Google GCC 4.9 </code>%0A<code>- $gcc32Type </code>%0A<code>xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</code>%0A%0A $MessageTag"
        tg_send_info "$MSG" 

		make -j${TotalCores}  ARCH=arm CROSS_COMPILE=$gcc32Dir/bin/$for32- "$DEFCONFIG"
		make -j${TotalCores}
			
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
	
	if [ ! -f $kernelDir/arch/arm/boot/zImage ];then
		getInfoErr ">> Compile Failed ! Aborting . . . . <<"
		SID="CAACAgUAAxkBAAIb12By2GpymhVy7G9g1Y5D2FcgvYr7AALZAQAC4dzJVslZcFisbk9nHgQ"
        MSG="<b>❌ Compile failed</b>%0AKernel Name : <b>${KName}</b>%0A- <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s)</code>%0A%0ASad Boy"
		
        tg_send_info "$MSG" 
		tg_send_sticker "$SID"
        exit -1
	else
		getInfo ">> Compiled Succesfully ! <<"
        cp -af $kernelDir/arch/arm/boot/zImage $AnykernelDir/anykernel
	fi
	
	getInfo ">> Building DTB .... <<"
	chmod +x ./dtbToolCM
	./dtbToolCM -2 -o ./arch/arm/boot/dt.img -s 2048 -p ./scripts/dtc/ ./arch/arm/boot/dts/
	if [ ! -e $kernelDir/arch/arm/boot/dt.img ];then
		getInfoErr ">> DTB Build Failed ! Aborting . . . . <<"
		SID="CAACAgUAAxkBAAIb12By2GpymhVy7G9g1Y5D2FcgvYr7AALZAQAC4dzJVslZcFisbk9nHgQ"
        MSG="<b>❌ DTB Build failed</b>%0AKernel Name : <b>${KName}</b>%0A- <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s)</code>%0A%0ASad Boy"
		
        tg_send_info "$MSG" 
		tg_send_sticker "$SID"
        exit -1
	else
		getInfo ">> DTB Builded Succesfully ! <<"
		cp -af $kernelDir/arch/arm/boot/dt.img $AnykernelDir/anykernel/dtb
	fi
		
		ZipName="$KName-$KVer.zip"
    ModAnyKernel
	MakeZip
}

# Modify AnyKernel
ModAnyKernel(){
	getInfo ">> Modifying info . . . . <<"
	cd $AnykernelDir/anykernel
	sed -i "s/kernel.string=.*/kernel.string=$KName/g" anykernel.sh
	cd $AnykernelDir
}

# Packing kernel
MakeZip(){
	getInfo ">> Packing Kernel . . . . <<"
    zip -r9 "$ZipName" * -x .git README.md anykernel-real.sh .gitignore *.zip
    tg_send_files
}

### Initial Script
getInfo '>> Initializing Script... <<'

mainDir=$PWD
kernelDir=$mainDir/kernel
gcc32Dir=$mainDir/gcc32
AnykernelDir=$mainDir/Anykernel3

git config --global user.name "$GIT_USERNAME"
git config --global user.email "$GIT_EMAIL"

getInfo ">> Cloning Kernel Source . . . <<"
git clone https://github.com/RyuujiX/android_kernel_xiaomi_gucci -b r1/s $kernelDir

getInfo ">> Cloning gcc32 . . . <<"
git clone https://github.com/RyuujiX/arm-linux-androideabi-4.9/ -b android-10.0.0_r47 $gcc32Dir --depth=1
for32=arm-linux-androideabi
getInfo ">> cloning Anykernel . . . <<"
git clone https://github.com/RyuujiX/AnyKernel3 -b gucci $AnykernelDir --depth=1

## Chat ID  
    FileChatID="-1001756316778"
	InfoChatID="-1001407005109"

## Kernel Setup	
    GetBD=$(date +"%m%d")
    GetCBD=$(date +"%Y-%m-%d")
	GetTime=$(date "+%T")
	GetDateTime=$(date)
    TotalCores=$(nproc --all)
	[[ "$(pwd)" != "${kernelDir}" ]] && cd "${kernelDir}"
	HeadCommitMsg=$(git log --pretty=format:'%s' -n1)
	DEFCONFIG="gucci_defconfig"
	DEFCONFIGPATH="arch/arm/configs"
    HeadCommitId=$(git log --pretty=format:'%h' -n1)
    cd $mainDir

## Get Toolchain Version
	if [ -e $gcc32Dir/bin/$for32-gcc ];then
        gcc32Type="$($gcc32Dir/bin/$for32-gcc --version | head -n 1)"
    else
        cd $gcc32Dir
        gcc32Type=$(git log --pretty=format:'%h: %s' -n1)
        cd $mainDir
    fi
	export KBUILD_BUILD_USER="RyuujiX"

getInfo '>> Script Initialized ! <<'

getInfo ">> Starting Build . . . . <<"
CompileKernel