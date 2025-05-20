
source /etc/profile
export |grep DOCKER_REG |grep -Ev "PASS|PW"
repo=registry.cn-shenzhen.aliyuncs.com
echo "${DOCKER_REGISTRY_PW_infrastSubUser2}" |docker login --username=${DOCKER_REGISTRY_USER_infrastSubUser2} --password-stdin $repo
repoHub=docker.io
echo "${DOCKER_REGISTRY_PW_dockerhub}" |docker login --username=${DOCKER_REGISTRY_USER_dockerhub} --password-stdin $repoHub


function doBuildx(){
    local tag=$1
    local dockerfile=$2

    repo=registry-1.docker.io
    # repo=registry.cn-shenzhen.aliyuncs.com
    test ! -z "$REPO" && repo=$REPO #@gitac
    img="docker-hdmi-desktop:$tag"
    # cache
    ali="registry.cn-shenzhen.aliyuncs.com"
    # request to https://registry.cn-shenzhen.aliyuncs.com/v2/infrastlabs/docker-hdmi-desktop/manifests/hdmi-cache: 403 Forbidden
    # cimg="docker-hdmi-desktop-cache:$tag"
    cimg="$img-cache"
    
    plat="--platform linux/amd64,linux/arm64" #,linux/arm
    plat="--platform linux/amd64" #dbg

    compile="alpine-compile"; builddate=$(date +%Y-%m-%d_%H:%M:%S)
    # test "$plat" != "--platform linux/amd64,linux/arm64,linux/arm" && compile="${compile}-dbg"
    # --build-arg REPO=$repo/ #temp notes, just use dockerHub's
    args="""
    --provenance=false 
    --build-arg VER=$tag
    --build-arg REPO=$repo/
    --build-arg COMPILE_IMG=$compile
    --build-arg NOCACHE=$builddate
    --build-arg BUILDDATE=$builddate
    """

    # cd flux
    # test "$plat" != "--platform linux/amd64,linux/arm64,linux/arm" && img="${img}-dbg"
    # test "$plat" != "--platform linux/amd64,linux/arm64,linux/arm" && cimg="${cimg}-dbg"
    
    # ref :3000/sam/quickstart-dockerfile >> mode=max
    #  oci-mediatypes=true,image-manifest=true,:ali-403-forbidden
    
    # # 暂取消cache模式
      # export REPO_ALI=registry.cn-shenzhen.aliyuncs.com
      # export REPO_TEN=ccr.ccs.tencentyun.com
      # export REPO_TEN_HK=hkccr.ccs.tencentyun.com #/infrastlabs/repo1
      # export REPO_QING=dockerhub.qingcloud.com #无Area.zone分区
      ali2=$REPO_TEN_HK
    cache="--cache-from type=registry,ref=$ali2/$ns/$cimg"
    cache="$cache --cache-to type=registry,ref=$ali2/$ns/$cimg,mode=max"
    # request to https://registry.cn-shenzhen.aliyuncs.com/v2/infrastlabs/docker-hdmi-desktop-cache/manifests/hdmi: 403 Forbidden
    # cache="$cache --cache-to type=registry,ref=$ali/$ns/$cimg"
    
    # drop: oci-mediatypes=true,:  还是403错
    # output="--output type=image,name=$repo/$ns/$img,push=true,annotation.author=sam"
    output="--output type=image,name=$repo/$ns/$img,push=true,oci-mediatypes=true,annotation.author=sam"
    docker buildx build $cache $plat $args $output -f $dockerfile . 

}

ns=infrastlabs
ver=v51 #base-v5 base-v5-slim
case "$1" in
# hdmi)
#     repo1=docker.io/ #ghcr.io/
#     # docker pull xx & ##wait并行导致被禁?
#     docker pull --platform=linux/amd64 ${repo1}balenalib/amd64-debian:buster
#     docker pull ${repo1}balenalib/aarch64-debian:buster #--platform=linux/aarch64_generic 
#     docker pull ${repo1}balenalib/armv7hf-debian:buster #--platform=linux/arm_cortex-a9_vfpv3-d16 
#     # 
#     dst=hkccr.ccs.tencentyun.com/infrasync/v2025:balenalib--debian---buster
#     docker tag ${repo1}balenalib/amd64-debian:buster $dst-amd64; docker push $dst-amd64
#     docker tag ${repo1}balenalib/aarch64-debian:buster $dst-arm64; docker push $dst-arm64
#     docker tag ${repo1}balenalib/armv7hf-debian:buster $dst-arm; docker push $dst-arm
#     docker images |grep ${dst%%---*}
#     # 
#     doBuildx latest src/Dockerfile
#     ;;
x11base-all)
    # doBuildx app-ubuntu2-22.04 src/Dockerfile.app-ubuntu2 &
    # wait 
    # exit 0

    doBuildx app-ubuntu-18.04 src/Dockerfile.app-ubuntu &
    doBuildx app-ubuntu-20.04 src/Dockerfile.app-ubuntu &
    doBuildx app-ubuntu-22.04 src/Dockerfile.app-ubuntu &
    doBuildx app-ubuntu-24.04 src/Dockerfile.app-ubuntu &
    # doBuildx app-ubuntu-26.04 src/Dockerfile.app-ubuntu &
    # wait
    # doBuildx app-opensuse-15.5 src/Dockerfile.zyp-opensuse &
    # doBuildx app-opensuse-15.6 src/Dockerfile.zyp-opensuse &
    # wait
    doBuildx app-alpine-3.13 src/Dockerfile.app-alpine & #xorgCrash@weipai_s11
    # doBuildx app-alpine-3.14 src/Dockerfile.app-alpine &
    # doBuildx app-alpine-3.16 src/Dockerfile.app-alpine &
    doBuildx app-alpine-3.19 src/Dockerfile.app-alpine &
    # doBuildx app-alpine-3.21 src/Dockerfile.app-alpine &
    doBuildx app-alpine-3.23 src/Dockerfile.app-alpine &
    # 
    # doBuildx core-debian-7 src/Dockerfile.app-debian & #err
    # doBuildx core-debian-8 src/Dockerfile.app-debian &
    doBuildx core-debian-9 src/Dockerfile.app-debian &
    doBuildx core-debian-10 src/Dockerfile.app-debian &
    doBuildx core-debian-11 src/Dockerfile.app-debian &
    doBuildx core-debian-12 src/Dockerfile.app-debian &
    # doBuildx core-debian-13 src/Dockerfile.app-debian &
    wait
    ;;    
*)
    # doBuildx $1 src/Dockerfile.$1
    echo "emp params"
    ;;          
esac