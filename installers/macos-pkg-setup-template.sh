set -e

PYTHON_FULL_VERSION="{{__VERSION_FULL__}}"
PYTHON_PKG_NAME="{{__PKG_NAME__}}"
MAJOR_VERSION=$(echo $PYTHON_FULL_VERSION | cut -d '.' -f 1)
MINOR_VERSION=$(echo $PYTHON_FULL_VERSION | cut -d '.' -f 2)

PYTHON_MAJOR=python$MAJOR_VERSION
PYTHON_MAJOR_DOT_MINOR=python$MAJOR_VERSION.$MINOR_VERSION
PYTHON_MAJORMINOR=python$MAJOR_VERSION$MINOR_VERSION

if [ -z ${AGENT_TOOLSDIRECTORY+x} ]; then
    # No AGENT_TOOLSDIRECTORY on GitHub images
    TOOLCACHE_ROOT=$RUNNER_TOOL_CACHE
else
    TOOLCACHE_ROOT=$AGENT_TOOLSDIRECTORY
fi

PYTHON_TOOLCACHE_PATH=$TOOLCACHE_ROOT/Python
PYTHON_TOOLCACHE_VERSION_PATH=$PYTHON_TOOLCACHE_PATH/$PYTHON_FULL_VERSION
PYTHON_TOOLCACHE_VERSION_ARCH_PATH=$PYTHON_TOOLCACHE_VERSION_PATH/x64

echo "Check if Python hostedtoolcache folder exist..."
if [ ! -d $PYTHON_TOOLCACHE_PATH ]; then
    echo "Creating Python hostedtoolcache folder..."
    mkdir -p $PYTHON_TOOLCACHE_PATH
else
    # remove ALL other directories for same major.minor python versions
    find $PYTHON_TOOLCACHE_PATH -name "${MAJOR_VERSION}.${MINOR_VERSION}.*"|while read python_version;do
        python_version_x64="$python_version/x64"
        if [ -e "$python_version_x64" ];then
            echo "Deleting Python $python_version_x64"
            rm -rf "$python_version_x64"
        fi
    done
fi

echo "Install Python binaries from prebuilt package"
sudo installer -pkg $PYTHON_PKG_NAME -target /

echo "Create hostedtoolcach symlinks (Required for the backward compatibility)"
echo "Create Python $PYTHON_FULL_VERSION folder"
mkdir -p $PYTHON_TOOLCACHE_VERSION_ARCH_PATH
cd $PYTHON_TOOLCACHE_VERSION_ARCH_PATH

ln -s /Library/Frameworks/Python.framework/Versions/${MAJOR_VERSION}.${MINOR_VERSION}/bin bin
ln -s /Library/Frameworks/Python.framework/Versions/${MAJOR_VERSION}.${MINOR_VERSION}/include include
ln -s /Library/Frameworks/Python.framework/Versions/${MAJOR_VERSION}.${MINOR_VERSION}/share share
ln -s /Library/Frameworks/Python.framework/Versions/${MAJOR_VERSION}.${MINOR_VERSION}/lib lib

echo "Create additional symlinks (Required for the UsePythonVersion Azure Pipelines task and the setup-python GitHub Action)"
ln -s ./bin/$PYTHON_MAJOR_DOT_MINOR python

cd bin/
ln -s $PYTHON_MAJOR_DOT_MINOR $PYTHON_MAJORMINOR
if [ ! -f python ]; then
    ln -s $PYTHON_MAJOR_DOT_MINOR python
fi

chmod +x ../python $PYTHON_MAJOR $PYTHON_MAJOR_DOT_MINOR $PYTHON_MAJORMINOR python

echo "Upgrading pip..."
./python -m ensurepip
./python -m pip install --ignore-installed pip --disable-pip-version-check --no-warn-script-location

echo "Create complete file"
touch $PYTHON_TOOLCACHE_VERSION_PATH/x64.complete
