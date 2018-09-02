<template>
<div>
  <el-button @click="addScreen">Add Screen</el-button>
  <el-button>Save &amp; Generate</el-button>
  <div style="margin-top: 20px">
    <el-card style="width: 200px; cursor: pointer;"
      :body-style="{ padding: '0px' }"
      v-for="screen in screens" :key="screen.name"
      shadow="hover" @click.native="openScreen(screen)">
      <div style="width: 200px; height: 200px; text-align: center;">
        <img :src="screen.dataurl" style="max-width: 200px; max-height: 200px;">
      </div>
      <div>{{ screen.name }}</div>
    </el-card>
  </div>
</div>
</template>

<script>
import fs from 'fs';
import Jimp from 'jimp';
import uuid from 'uuid';
import path from 'path';
import { Screen } from "../Screen";

export default {
  name: 'list-view',
  props: ['screens', 'path'],
  methods: {
    async addScreen() {
      const screen = new Screen();
      const [imagePath] = this.$electron.remote.dialog.showOpenDialog({
        message: 'select image',
        properties: ['openFile', ],
        filters: [
          { name: 'Images', extensions: ['jpg', 'png', 'gif'] },
        ],
      });
      const image = await Jimp.read(imagePath);
      try {
        fs.mkdirSync(path.join(this.path, 'screens'));
      } catch (error) {
        // ignore error
      }
      const localPath = path.join(this.path, 'screens', `${uuid()}.png`);
      await new Promise(r => image.write(localPath, r));
      screen.image = localPath;
      screen.dataurl = await image.getBase64Async('image/png');
      this.screens.push(screen);
      this.$emit('open', screen);
    },
    delScreen(screen) {
      this.screens.delScreen(screen);
    },
    openScreen(screen) {
      console.log(screen);
      this.$emit('open', screen);
    },
  },
}
</script>

