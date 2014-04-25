#!/bin/bash
source $(dirname $0)/defaults.sh

# compile neko
if [ ! -f /usr/bin/neko ]; then
	sudo rm -f /usr/bin/neko*
	sudo rm -f /usr/lib/libneko*
	sudo rm -rf /usr/lib/neko
	install libgc1c2 bdw-gc # boehm gc
	install libpcre3 pcre # pcre
	install zlib1g libzip # zlib
	if [ $OS = "mac" ]; then
		echo "no prebuilt binary available; building neko"
		retry git clone https://github.com/HaxeFoundation/neko.git ~/neko
		cd ~/neko && make clean && make LIB_PREFIX=/usr/local os=osx INSTALL_FLAGS= && sudo make install os=osx
		sudo cp -Rf ~/neko/bin /usr/lib/neko
	else
		retry wget -O ~/neko.tgz "http://nekovm.org/_media/neko-2.0.0-$OS$NEKO_ARCH.tar.gz"
		tar -zxf ~/neko.tgz -C ~/
		rm ~/neko.tgz
		cd ~/neko*
		sudo mkdir -p /usr/lib/neko
		sudo cp -Rf * /usr/lib/neko
		sudo ln -s /usr/lib/neko/neko* /usr/bin
		sudo ln -s /usr/lib/neko/lib* /usr/lib
	fi
fi

neko -version || exit 1
echo "neko v$(neko -version)"

# get haxe
echo "getting haxe"
sudo rm -rf /usr/lib/haxe
sudo rm -f /usr/bin/haxe*
DIR=$OS$ARCH_BITS
if [ $OS = "mac" ]; then
	DIR=mac
fi
retry wget -O ~/haxe.tgz "http://hxbuilds.s3-website-us-east-1.amazonaws.com/builds/haxe/$DIR/haxe_latest.tar.gz"
cd ~
tar -zxf haxe.tgz
cd haxe*
sudo mkdir -p /usr/lib/haxe
sudo cp -Rf * /usr/lib/haxe
sudo ln -s /usr/lib/haxe/haxe* /usr/bin
haxe 2>&1 | head -n 1 || exit 1

# setup haxelib
echo "setup haxelib"
mkdir -p ~/haxelib && haxelib setup ~/haxelib || exit 1

case $SETUP in
	php )
		testprog php -v || install php5-cli || install php5
		;;
	cpp )
		install gcc-multilib
		install g++-multilib
		retry haxelib git hxcpp https://github.com/HaxeFoundation/hxcpp
		cd ~/haxelib/hxcpp/git/project
		if [ $OS = "mac" ]; then
			neko build.n mac-m32 mac-m64 -DHXCPP_GCC || exit 1
		else
			neko build.n || exit 1
		fi
		;;
	java )
		testprog javac -version || install openjdk || sudo apt-get install -y openjdk-7-jdk || install openjdk-7-jdk || exit 1
		retry haxelib git hxjava https://github.com/HaxeFoundation/hxjava
		javac -version || exit 1
		;;
	cs )
		testprog mcs --version || install mono-mcs mono || sudo apt-get install -y mono-mcs || exit 1
		retry haxelib git hxcs https://github.com/HaxeFoundation/hxcs
		mcs --version || exit 1
		;;
	flash | as3 | swf | swf9 | swf8 )
		if [ $OS = "mac" ]; then
			retry wget http://waneck-pub.s3-website-us-east-1.amazonaws.com/unitdeps/flashplayer-dbg-osx.tar.gz -O ~/flash.tar.gz
			tar -xvf ~/flash.tar.gz -C ~/
			# ln -s "~/flashplayer.app/Contents/MacOS/Flash Player Debugger" ~/flashplayerdebugger
			if [ $SETUP = "as3" ] && [ ! mxmlc --version ]; then
				retry wget -O ~/flex.tar.gz http://waneck-pub.s3-website-us-east-1.amazonaws.com/unitdeps/flex_sdk_4.mac.tar.gz
				tar -xvf ~/flex.tar.gz -C ~
				mxmlc --version || exit 1
			fi
		else
			# TODO if the following doesn't work, uncomment either the next lines
			retry wget http://waneck-pub.s3-website-us-east-1.amazonaws.com/unitdeps/flashplayer_11_sa_debug.i386.min.tar.xz
			# retry wget http://waneck-pub.s3-website-us-east-1.amazonaws.com/unitdeps/flashplayer_11_sa_debug.i386.tar.gz
			# retry wget http://fpdownload.macromedia.com/pub/flashplayer/updaters/11/flashplayer_11_sa_debug.i386.tar.gz
			install libgd2-xpm ; install ia32-libs ; install ia32-libs-multiarch ; install libgtk2.0-0:i386 ; install libxt6:i386 ; install libnss3:i386
			[ -f /etc/init.d/xvfb ] || install xvfb
			# retry sudo apt-get install -qq -y libgd2-xpm ia32-libs ia32-libs-multiarch
			tar -xvf flashplayer* -C ~/
			echo "ErrorReportingEnable=1\nTraceOutputFileEnable=1" > ~/mm.cfg
			if [ $SETUP = "as3" ] && [ ! mxmlc --version ]; then
				#TODO if the following doesn't work, uncomment either the next lines
				retry wget -O ~/flex.tar.xz http://waneck-pub.s3-website-us-east-1.amazonaws.com/unitdeps/apache-flex-sdk-4.12.0-bin-min.tar.xz
				#retry wget -O ~/flex.tar.gz http://waneck-pub.s3-website-us-east-1.amazonaws.com/unitdeps/apache-flex-sdk-4.12.0-bin.tar.gz
				#retry wget -O ~/flex.tar.gz http://mirror.cc.columbia.edu/pub/software/apache/flex/4.12.0/binaries/apache-flex-sdk-4.12.0-bin.tar.gz
				tar -xvf ~/flex.tar.* -C ~
				mv $HOME/apache-flex-sdk-4.12.0-bin/ $HOME/flex_sdk_4
				mkdir -p $FLEXPATH/player/11.1
				retry wget -nv http://download.macromedia.com/get/flashplayer/updaters/11/playerglobal11_1.swc -O "$FLEXPATH/player/11.1/playerglobal.swc"
				echo "env.PLAYERGLOBAL_HOME=$FLEXPATH/player" > $FLEXPATH/env.properties
				testprog java -version || install openjdk-7-jdk || exit 1
				mxmlc --version || exit 1
			fi
			# ~/runflash || exit 1
		fi
		;;
	js )
		if [ $TOOLCHAIN = "default" ] || [ $TOOLCHAIN = "nodejs" ]; then
			testprog nodejs -v || testprog node -v || install nodejs node
			testprog nodejs -v || testprog nods -v || exit 1
		elif [ $TOOLCHAIN = "browser" ]; then
			testprog phantomjs -v || install phantomjs
			phantomjs -v || exit 1
		fi
		;;
	* )
		;;
esac

cd $TRAVIS_BUILD_DIR
