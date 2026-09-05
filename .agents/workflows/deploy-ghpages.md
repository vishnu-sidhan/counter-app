---
description: Builds the Flutter web project and force pushes the artifacts directly to the gh-pages branch.
---

# Deploy Flutter Web to gh-pages Branch

Execute the following commands sequentially in the project root terminal:

```bash
flutter build web --release --base-href "/counter-app/"
cd build/web
git init
git checkout -b gh-pages
git add .
git commit -m "deploy: update GitHub Pages build"
git push --force [https://github.com/vishnu-sidhan/counter-app.git](https://github.com/vishnu-sidhan/counter-app.git) gh-pages
cd ../..
```

After the commands finish, confirm the deployment status and remind the user of the site link:

Target URL: https://vishnu-sidhan.github.io/counter-app/
