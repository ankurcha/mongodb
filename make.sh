#!/bin/sh 
# ------------------------------------------------
# (c) 2009-2010 Vanilladesk Ltd., http://www.vanilladesk.com
# ------------------------------------------------

app_name="mongodb"
app_version="1.8.1"
package_name="vd-install-$app_name-$app_version"

build_folder=~/build
temp_folder=/tmp/$app_name
start_folder="$PWD"

[ -d "$temp_folder" ] || mkdir $temp_folder
[ -d "$build_folder" ] || mkdir $build_folder

# Copy files to temporary folder
mkdir -p $temp_folder/$package_name
cp -R * $temp_folder/$package_name

# remove not needed files so they will not appear in the package
pushd $temp_folder/$package_name > /dev/nul

rm make.sh

popd > /dev/nul

# create final package

pushd $temp_folder > /dev/nul
tar czf $build_folder/$package_name.tar.gz * --exclude=.git*
popd > /dev/nul

rm -R $temp_folder

echo "Done. Package is available at $build_folder/$package_name.tar.gz"