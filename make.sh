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

rm $temp_folder/$package_name/make.sh
cd $temp_folder/$package_name

# create final package

tar czf $build_folder/$package_name.tar.gz * 
cd ../..

rm -R $temp_folder

echo "Done. Package is available at $build_folder/$package_name.tar.gz"
