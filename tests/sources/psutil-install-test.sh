# Check if shared libraries are linked correctly
python -m venv /tmp/aml-ve
source /tmp/aml-ve/bin/activate
easy_install --version
pip install psutil --verbose