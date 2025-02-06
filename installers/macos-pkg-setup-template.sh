set -e

PYTHON_FULL_VERSION="{{__VERSION_FULL__}}"
PYTHON_PKG_NAME="{{__PKG_NAME__}}"
PYTHON_FRAMEWORK_NAME="{{__FRAMEWORK_NAME__}}"
PYTHON_PKG_CHOICES=$(cat << 'EOF'
{{__PKG_CHOICES__}}
EOF
)
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
PYTHON_FRAMEWORK_PATH="/Library/Frameworks/${PYTHON_FRAMEWORK_NAME}/Versions/${MAJOR_VERSION}.${MINOR_VERSION}"
PYTHON_APPLICATION_PATH="/Applications/Python ${MAJOR_VERSION}.${MINOR_VERSION}"

echo "Check if Python hostedtoolcache folder exist..."
if [ ! -d $PYTHON_TOOLCACHE_PATH ]; then
    echo "Creating Python hostedtoolcache folder..."
    mkdir -p $PYTHON_TOOLCACHE_PATH
else
    # remove ALL other directories for same major.minor python versions
    find $PYTHON_TOOLCACHE_PATH -name "${MAJOR_VERSION}.${MINOR_VERSION}.*"|while read python_version;do
        python_version_arch="$python_version/$ARCH"
        if [ -e "$python_version_arch" ];then
            echo "Deleting Python $python_version_arch"
            rm -rf "$python_version_arch"
        fi
    done
fi

PYTHON_PKG_CHOICES_FILES=$(mktemp)
echo "$PYTHON_PKG_CHOICES" > $PYTHON_PKG_CHOICES_FILES

echo "Install Python binaries from prebuilt package"
sudo installer -pkg $PYTHON_PKG_NAME -applyChoiceChangesXML $PYTHON_PKG_CHOICES_FILES -target /

echo "Create hostedtoolcach symlinks (Required for the backward compatibility)"
echo "Create Python $PYTHON_FULL_VERSION folder"
mkdir -p $PYTHON_TOOLCACHE_VERSION_ARCH_PATH
cd $PYTHON_TOOLCACHE_VERSION_ARCH_PATH

ln -s "${PYTHON_FRAMEWORK_PATH}/bin" bin
ln -s "${PYTHON_FRAMEWORK_PATH}/include" include
ln -s "${PYTHON_FRAMEWORK_PATH}/share" share
ln -s "${PYTHON_FRAMEWORK_PATH}/lib" lib

echo "Create additional symlinks (Required for the UsePythonVersion Azure Pipelines task and the setup-python GitHub Action)"
ln -s ./bin/$PYTHON_MAJOR_DOT_MINOR python
chmod +x python

# Note that bin is a symlink so referencing .. from bin will not work as expected
cd bin/

# This symlink already exists if Python version with the same major.minor version is installed,
# since we do not remove the framework folder
if [ ! -f $PYTHON_MAJOR_MINOR ]; then
    ln -s $PYTHON_MAJOR_DOT_MINOR $PYTHON_MAJOR_MINOR
fi

if [ ! -f $PYTHON_MAJOR ]; then
    ln -s $PYTHON_MAJOR_DOT_MINOR $PYTHON_MAJOR
fi

if [ ! -f python ]; then
    ln -s $PYTHON_MAJOR_DOT_MINOR python
fi

chmod +x $PYTHON_MAJOR $PYTHON_MAJOR_DOT_MINOR $PYTHON_MAJOR_MINOR python

echo "Upgrading pip..."
export PIP_ROOT_USER_ACTION=ignore
./python -m ensurepip
./python -m pip install --upgrade --force-reinstall pip --disable-pip-version-check --no-warn-script-location

echo "Install OpenSSL certificates"
sh -e "${PYTHON_APPLICATION_PATH}/Install Certificates.command"

echo "Create complete file"
touch $PYTHON_TOOLCACHE_VERSION_PATH/${ARCH}.complete
