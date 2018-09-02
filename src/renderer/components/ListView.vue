<template>
<div>
  <el-button @click="addScreen">Add Screen</el-button>
  <el-button @click="saveGenerate">Save &amp; Generate</el-button>
  <div style="margin-top: 20px">
    <el-card style="width: 200px; float: left; margin: 10px;"
      :body-style="{ padding: '0px' }"
      v-for="screen in screens.screens" :key="screen.name"
      shadow="hover">
      <div @click="openScreen(screen)" style="width: 200px; height: 200px; text-align: center; cursor: pointer;">
        <img :src="screen.dataurl" style="max-width: 200px; max-height: 200px;">
      </div>
      <div style="padding: 7px;">
        <span>{{ screen.name }}</span>
        <div style="margin: 7px; float: right;">
          <el-button @click="delScreen(screen)" size="mini" type="danger" icon="el-icon-delete" circle></el-button>
        </div>
      </div>
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
      await image.writeAsync(localPath);
      screen.image = localPath;
      screen.dataurl = await image.getBase64Async('image/png');
      this.screens.add(screen);
      this.$emit('open', screen);
    },
    delScreen(screen) {
      this.screens.del(screen);
    },
    openScreen(screen) {
      this.$emit('open', screen);
    },
    async saveGenerate() {
      await this.screens.save();
      await this.screens.generate();
      await this.screens.save();
    },
  },
}
</script>

