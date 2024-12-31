#!/bin/bash

usage(){
    echo "usage: ./build.single.sh [-p|--package [audio|full|full-gpl|https|https-gpl|min|min-gpl|video]] [-c|--clean-output] [-v|--verbose] [-o|--output-path path]"
    echo "parameters:"
    echo "  -p | --package [audio|full|full-gpl|https|https-gpl|min|min-gpl|video]    REQUIRED, See https://github.com/tanersener/mobile-ffmpeg for more information"
    echo "  -c | --clean-output                                                       Cleans the output before building"
    echo "  -v | --verbose                                                            Enable verbose build details from msbuild tasks"
    echo "  -h | --help                                                               Prints this message"
    echo
}

while [ "$1" != "" ]; do
    case $1 in
        -p | --package )        shift
                                package_variant=$1
                                ;;
        -c | --clean-output )   clean_output=1
                                ;;
        -v | --verbose )        verbose=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     echo
                                echo "### Wrong parameter: $1 ###"
                                echo
                                usage
                                exit 1
    esac
    shift
done

# Required variables
if [ -z "$package_variant" ]; then
    usage
    exit 1
fi

# find the latest ID here : https://api.github.com/repos/arthenica/ffmpeg-kit/releases
github_repo_owner=arthenica
github_repo=ffmpeg-kit
github_release_id=118272646
github_info_file="$github_repo_owner.$github_repo.$github_release_id.info.json"

if [ ! -f "$github_info_file" ]; then
    echo ""
    echo "### DOWNLOAD GITHUB INFORMATION ###"
    echo ""
    github_info_file_url=https://api.github.com/repos/$github_repo_owner/$github_repo/releases/$github_release_id
    echo "Downloading $github_info_file_url to $github_info_file"
    curl -s $github_info_file_url > $github_info_file
fi

echo ""
echo "### INFORMATION ###"
echo ""

# Set version
# Figure out how to grep 6.0-2.LTS instead of 6.0.LTS
# github_tag_name=`cat $github_info_file | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//'`
github_tag_name=`echo "6.0-2.LTS"` 
github_short_version=`echo "$github_tag_name" | sed 's/.LTS//'`

# see https://github.com/tanersener/mobile-ffmpeg for more information
package_libraries="?"
[ "$package_variant" = "audio" ] && package_libraries="lame libilbc libvorbis opencore-amr opus shine soxr speex twolame vo-amrwbenc wavpack"
[ "$package_variant" = "full" ] && package_libraries="fontconfig freetype fribidi gmp gnutls kvazaar lame libaom libass libiconv libilbc libtheora libvorbis libvpx libwebp libxml2 opencore-amr opus shine snappy soxr speex twolame vo-amrwbenc wavpack"
[ "$package_variant" = "full-gpl" ] && package_libraries="fontconfig freetype fribidi gmp gnutls kvazaar lame libaom libass libiconv libilbc libtheora libvorbis libvpx libwebp libxml2 opencore-amr opus shine snappy soxr speex twolame vid.stab vo-amrwbenc wavpack x264 x265 xvidcore"
[ "$package_variant" = "https" ] && package_libraries="gmp gnutls"
[ "$package_variant" = "https-gpl" ] && package_libraries="gmp gnutls vid.stab x264 x265 xvidcore"
[ "$package_variant" = "min" ] && package_libraries="-"
[ "$package_variant" = "min-gpl" ] && package_libraries="vid.stab x264 x265 xvidcore"
[ "$package_variant" = "video" ] && package_libraries="fontconfig freetype fribidi kvazaar libaom libass libiconv libtheora libvpx libwebp snappy"

nuget_variant="$package_variant"
[ "$package_variant" = "audio" ] && nuget_variant="Audio"
[ "$package_variant" = "full" ] && nuget_variant="Full"
[ "$package_variant" = "full-gpl" ] && nuget_variant="Full.Gpl"
[ "$package_variant" = "https" ] && nuget_variant="Https"
[ "$package_variant" = "https-gpl" ] && nuget_variant="Https.Gpl"
[ "$package_variant" = "min" ] && nuget_variant="Min"
[ "$package_variant" = "min-gpl" ] && nuget_variant="Min.Gpl"
[ "$package_variant" = "video" ] && nuget_variant="Video"

# Static configuration
nuget_project_folder="Laerdal.FFmpeg.Android"
nuget_project_name="Laerdal.FFmpeg.Android"
nuget_output_folder="$nuget_project_name.Output"
nuget_csproj_path="$nuget_project_folder/$nuget_project_name.csproj"

nuget_jars_folder="$nuget_project_folder/Jars"

package_aar_folder="$nuget_project_name.Source"
package_aar_file_name="ffmpeg-kit-$package_variant-$github_tag_name.aar"
package_aar_file="$package_aar_folder/$package_aar_file_name"

# Generates variables
echo "github_repo_owner = $github_repo_owner"
echo "github_repo = $github_repo"
echo "github_release_id = $github_release_id"
echo "github_info_file = $github_info_file"
echo "github_tag_name = $github_tag_name"
echo "github_short_version = $github_short_version"
echo ""
echo "package_variant = $package_variant"
echo "package_libraries = $package_libraries"
echo "package_aar_folder = $package_aar_folder"
echo "package_aar_file_name = $package_aar_file_name"
echo "package_aar_file = $package_aar_file"
echo ""
echo "nuget_variant = $nuget_variant"
echo "nuget_project_folder = $nuget_project_folder"
echo "nuget_output_folder = $nuget_output_folder"
echo "nuget_project_name = $nuget_project_name"
echo "nuget_jars_folder = $nuget_jars_folder"
echo "nuget_csproj_path = $nuget_csproj_path"

if [ "$clean_output" = "1" ]; then
    echo
    echo "### CLEAN OUTPUT ###"
    echo
    rm -rf $nuget_output_folder/$nuget_variant
    echo "Deleted : $nuget_output_folder/$nuget_variant"
fi

echo
echo "### SETTING GITVERSION NEXT-VERSION  ###"
echo
echo "next-version: $github_short_version"
sed -i -E "s/next-version:.*/next-version: $github_short_version/" $nuget_project_folder/GitVersion.yml

echo ""
echo "### DOWNLOAD GITHUB RELEASE FILES ###"
echo ""

mkdir -p $package_aar_folder

echo "Files matching '$package_aar_file_name' :"
cat $github_info_file | grep "browser_download_url.*$package_aar_file_name" | cut -d : -f 2,3 | tr -d \"

wget_parameters="-q" # Quiet
if [ "$verbose" = "1" ]; then
    wget_parameters="${wget_parameters} --show-progress" # Force wget to display the progress bar.
fi
wget_parameters="${wget_parameters} -nc" # --no-clobber = keep existing file
wget_parameters="${wget_parameters} -P $package_aar_folder" #--directory-prefix = Output directory
wget_parameters="${wget_parameters} -i -" # Input (If you specify ‘-’ as file name, the URLs will be read from standard input.)

echo ""
echo "wget_parameters = $wget_parameters"
cat $github_info_file | grep "browser_download_url.*$package_aar_file_name" | cut -d : -f 2,3 | tr -d \" | wget $wget_parameters

if [ ! -f "$package_aar_file" ]; then
    echo "Failed : Can't find '$package_aar_file'"
    exit 1
fi

echo ""
echo "### COPY AAR FILE ###"
echo ""

echo "Copying $package_aar_file to $nuget_jars_folder/ffmpeg-kit.aar"
rm -rf $nuget_jars_folder/ffmpeg-kit.aar
mkdir -p $nuget_jars_folder
cp $package_aar_file $nuget_jars_folder/ffmpeg-kit.aar

echo ""
echo "### MSBUILD ###"
echo ""

msbuild_parameters=""
if [ ! "$verbose" = "1" ]; then
    msbuild_parameters="${msbuild_parameters} -nologo -verbosity:quiet"
fi
msbuild_parameters="${msbuild_parameters} -t:Rebuild"
msbuild_parameters="${msbuild_parameters} -restore:True"
msbuild_parameters="${msbuild_parameters} -p:Configuration=Release"
msbuild_parameters="${msbuild_parameters} -p:NugetPackageVariantName=$nuget_variant"
msbuild_parameters="${msbuild_parameters} -p:ExternalLibraries=\"$package_libraries\""
echo "msbuild_parameters = $msbuild_parameters"
echo ""

rm -rf $nuget_project_folder/bin
rm -rf $nuget_project_folder/obj
msbuild $nuget_csproj_path $msbuild_parameters
