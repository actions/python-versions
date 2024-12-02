set -e

PYTHON_FULL_VERSION="{{__VERSION_FULL__}}"
PYTHON_PKG_NAME="{{__PKG_NAME__}}"
ARCH="{{__ARCH__}}"
MAJOR_VERSION=$(echo $PYTHON_FULL_VERSION | cut -d '.' -f 1)
MINOR_VERSION=$(echo $PYTHON_FULL_VERSION | cut -d '.' -f 2)

PYTHON_MAJOR=python$MAJOR_VERSION
PYTHON_MAJOR_DOT_MINOR=python$MAJOR_VERSION.$MINOR_VERSION
PYTHON_MAJOR_MINOR=python$MAJOR_VERSION$MINOR_VERSION

if [ -z ${AGENT_TOOLSDIRECTORY+x} ]; then
    # No AGENT_TOOLSDIRECTORY on GitHub images
    TOOLCACHE_ROOT=$RUNNER_TOOL_CACHE
else
    TOOLCACHE_ROOT=$AGENT_TOOLSDIRECTORY
fi

PYTHON_TOOLCACHE_PATH=$TOOLCACHE_ROOT/Python
PYTHON_TOOLCACHE_VERSION_PATH=$PYTHON_TOOLCACHE_PATH/$PYTHON_FULL_VERSION
PYTHON_TOOLCACHE_VERSION_ARCH_PATH=$PYTHON_TOOLCACHE_VERSION_PATH/$ARCH
PYTHON_FRAMEWORK_PATH="/Library/Frameworks/Python.framework/Versions/${MAJOR_VERSION}.${MINOR_VERSION}"
PYTHON_APPLICATION_PATH="/Applications/Python ${MAJOR_VERSION}.${MINOR_VERSION}"

# Check if zlib is installed
echo "Checking if zlib is installed..."
if ! brew list zlib &>/dev/null; then
    echo "Installing zlib via brew..."
    brew install zlib
else
    echo "zlib already installed."
fi

# Only for Python 3.7.17, install additional dependencies like zlib and others
if [ "$MAJOR_VERSION" -eq 3 ] && [ "$MINOR_VERSION" -eq 7 ] && [ "$PYTHON_FULL_VERSION" == "3.7.17" ]; then
    echo "Installing additional dependencies for Python 3.7.17..."
    brew install bzip2 readline ncurses sqlite3 openssl@3
    # Ensure the environment variables for zlib are set correctly
    ZLIB_PREFIX=$(brew --prefix zlib)
    export LDFLAGS="-L${ZLIB_PREFIX}/lib"
    export CFLAGS="-I${ZLIB_PREFIX}/include"
    export CPPFLAGS="-I${ZLIB_PREFIX}/include"
    echo "zlib linked at ${ZLIB_PREFIX}/lib"
fi

# Check if Python hostedtoolcache folder exists...
echo "Check if Python hostedtoolcache folder exists..."
if [ ! -d $PYTHON_TOOLCACHE_PATH ]; then
    echo "Creating Python hostedtoolcache folder..."
    mkdir -p $PYTHON_TOOLCACHE_PATH
else
    # Remove ALL other directories for same major.minor python versions
    find $PYTHON_TOOLCACHE_PATH -name "${MAJOR_VERSION}.${MINOR_VERSION}.*" | while read python_version; do
        python_version_arch="$python_version/$ARCH"
        if [ -e "$python_version_arch" ]; then
            echo "Deleting Python $python_version_arch"
            rm -rf "$python_version_arch"
        fi
    done
fi

echo "Installing Python binaries from prebuilt package"
sudo installer -pkg $PYTHON_PKG_NAME -target /

echo "Creating hostedtoolcache symlinks (Required for the backward compatibility)"
echo "Create Python $PYTHON_FULL_VERSION folder"
mkdir -p $PYTHON_TOOLCACHE_VERSION_ARCH_PATH
cd $PYTHON_TOOLCACHE_VERSION_ARCH_PATH

ln -s "${PYTHON_FRAMEWORK_PATH}/bin" bin
ln -s "${PYTHON_FRAMEWORK_PATH}/include" include
ln -s "${PYTHON_FRAMEWORK_PATH}/share" share
ln -s "${PYTHON_FRAMEWORK_PATH}/lib" lib

echo "Creating additional symlinks (Required for the UsePythonVersion Azure Pipelines task and the setup-python GitHub Action)"
ln -s ./bin/$PYTHON_MAJOR_DOT_MINOR python

cd bin/

# This symlink already exists if Python version with the same major.minor version is installed,
# since we do not remove the framework folder
if [ ! -f $PYTHON_MAJOR_MINOR ]; then
    ln -s $PYTHON_MAJOR_DOT_MINOR $PYTHON_MAJOR_MINOR
fi

if [ ! -f python ]; then
    ln -s $PYTHON_MAJOR_DOT_MINOR python
fi

chmod +x ../python $PYTHON_MAJOR $PYTHON_MAJOR_DOT_MINOR $PYTHON_MAJOR_MINOR python

echo "Upgrading pip..."
export PIP_ROOT_USER_ACTION=ignore
./python -m ensurepip
./python -m pip install --upgrade --force-reinstall pip --disable-pip-version-check --no-warn-script-location

echo "Installing OpenSSL certificates"
sh -e "${PYTHON_APPLICATION_PATH}/Install Certificates.command"

echo "Creating complete file"
touch $PYTHON_TOOLCACHE_VERSION_PATH/${ARCH}.complete
