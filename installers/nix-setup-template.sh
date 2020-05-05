set -e

MAJOR_VERSION="{{__VERSION_MAJOR__}}"
MINOR_VERSION="{{__VERSION_MINOR__}}"
BUILD_VERSION="{{__VERSION_BUILD__}}"

PYTHON_MAJOR=python$MAJOR_VERSION
PYTHON_MAJOR_DOT_MINOR=python$MAJOR_VERSION.$MINOR_VERSION
PYTHON_MAJORMINOR=python$MAJOR_VERSION$MINOR_VERSION
PYTHON_FULL_VERSION=$MAJOR_VERSION.$MINOR_VERSION.$BUILD_VERSION

PYTHON_TOOLCACHE_PATH=$AGENT_TOOLSDIRECTORY/Python
PYTHON_TOOLCACHE_VERSION_PATH=$PYTHON_TOOLCACHE_PATH/$PYTHON_FULL_VERSION
PYTHON_TOOLCACHE_VERSION_ARCH_PATH=$PYTHON_TOOLCACHE_VERSION_PATH/x64

echo "Check if Python hostedtoolcache folder exist..."
if [ ! -d $PYTHON_TOOLCACHE_PATH ]; then
    echo "Creating Python hostedtoolcache folder..."
    mkdir -p $PYTHON_TOOLCACHE_PATH
elif [ -d $PYTHON_TOOLCACHE_VERSION_PATH ]; then
    echo "Deleting Python $PYTHON_FULL_VERSION"
    rm -rf $PYTHON_TOOLCACHE_VERSION_PATH
fi

echo "Create Python $PYTHON_FULL_VERSION folder"
mkdir -p $PYTHON_TOOLCACHE_VERSION_ARCH_PATH

echo "Copy Python binaries to hostedtoolcache folder"
cp -R ./* $PYTHON_TOOLCACHE_VERSION_ARCH_PATH
rm $PYTHON_TOOLCACHE_VERSION_ARCH_PATH/setup.sh

cd $PYTHON_TOOLCACHE_VERSION_ARCH_PATH

echo "Create additional symlinks (Required for UsePythonVersion VSTS task)"
ln -s ./bin/$PYTHON_MAJOR_DOT_MINOR python

cd bin/
ln -s $PYTHON_MAJOR_DOT_MINOR $PYTHON_MAJORMINOR
if [ ! -f python ]; then
    ln -s $PYTHON_MAJOR_DOT_MINOR python
fi

chmod +x ../python $PYTHON_MAJOR $PYTHON_MAJOR_DOT_MINOR $PYTHON_MAJORMINOR python

echo "Upgrading PIP..."
./python -m ensurepip
./python -m pip install --ignore-installed pip

echo "Create complete file"
touch $PYTHON_TOOLCACHE_VERSION_PATH/x64.complete