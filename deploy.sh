#!/usr/bin/env sh

# 确保脚本抛出遇到的错误
set -e

# # 生成静态文件
yarn build

# 进入生成的文件夹
cd build

# 如果是发布到自定义域名
# echo 'www.example.com' > CNAME

git init
git add .
git commit -m 'deploy'

# 如果发布到 https://<USERNAME>.github.io
# 在这里，请更改成你的仓库地址
git push -f git@github.com:Zzhiter/Zzhiter.github.io.git master


# 如果发布到 https://<USERNAME>.github.io/<REPO>
# git push -f git@github.com:messiahhh/blog.git master:gh-pages
# git push -f https://${access_token}@github.com/Dcose/dcose.github.io.git master:gh-pages

cd -
