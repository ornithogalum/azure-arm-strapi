#!/bin/bash
apt update && apt upgrade -y
apt install libpng-dev build-essential -y
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list 
apt update && apt install yarn -y
node -v && npm -v && yarn -v
adduser --shell /bin/bash --disabled-login --gecos "" --quiet strapi
mkdir /srv/strapi
apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.4/ubuntu bionic main'
apt update && apt install mariadb-server-10.4 -y
mysql -u root -e "create database strapi_dev;"
mysql -u root -e "create user strapi@localhost identified by 'mysecurepassword';"
mysql -u root -e "grant all privileges on strapi_dev.* to strapi@localhost;"
mysql -u root -e "FLUSH PRIVILEGES;"
chown -R strapi:strapi /srv/strapi
sudo su strapi
cd /srv/strapi/
yarn create strapi-app blog --quickstart --no-run
cd /srv/strapi/blog/
rm -rf config/database.js
cat << EOF > config/database.js 
// path: /srv/strapi/mystrapiapp/config/database.js
module.exports = ({ env }) => ({
  connection: {
    client: 'mysql',
    connection: {
      host: env('DB_HOST'),
      port: env.int('DB_PORT'),
      database: env('DB_NAME'),
      user: env('DB_USER'),
      password: env('DB_PASS'),
//      ssl: {
//        rejectUnauthorized: env.bool('DATABASE_SSL_SELF', false), // For self-signed certificates
//      },
    },
    debug: false,
  },
});
EOF
npm install mysql
npm run build
yarn global add pm2
echo 'export PATH="$PATH:$(yarn global bin)"' >> ~/.bashrc
source ~/.bashrc
pm2 init
rm ecosystem.config.js
cat << EOF > ecosystem.config.js
module.exports = {
  apps: [
    {
      name: 'strapi-dev',
      cwd: '/srv/strapi/blog',
      script: 'npm',
      args: 'start',
      env: {
        NODE_ENV: 'development',
        DB_HOST: 'localhost',
        DB_PORT: '3306',
        DB_NAME: 'strapi_dev',
        DB_USER: 'strapi',
        DB_PASS: 'mysecurepassword',
        JWT_SECRET: 'aSecretKey',
      },
    },
  ],
};
EOF
rm package.json
cat << EOF > package.json
{
  "name": "blog",
  "private": true,
  "version": "0.1.0",
  "description": "A Strapi application",
  "scripts": {
    "develop": "strapi develop",
    "start": "strapi develop",
    "build": "strapi build",
    "strapi": "strapi"
  },
  "devDependencies": {},
  "dependencies": {
    "@strapi/strapi": "4.24.4",
    "@strapi/plugin-users-permissions": "4.24.4",
    "@strapi/plugin-i18n": "4.24.4",
    "@strapi/plugin-cloud": "4.24.4",
    "better-sqlite3": "8.6.0",
    "react": "^18.0.0",
    "react-dom": "^18.0.0",
    "react-router-dom": "5.3.4",
    "styled-components": "5.3.3"
  },
  "author": {
    "name": "A Strapi developer"
  },
  "strapi": {
    "uuid": "c6123ccc-9c4a-4853-b26c-40c72a5cf66d"
  },
  "engines": {
    "node": ">=18.0.0 <=20.x.x",
    "npm": ">=6.0.0"
  },
  "license": "MIT"
}
EOF
pm2 start ecosystem.config.js
pm2 startup systemd
exit
env PATH=$PATH:/usr/bin /home/strapi/.config/yarn/global/node_modules/pm2/bin/pm2 startup systemd -u strapi --hp /home/strapi
sudo su strapi
pm2 save