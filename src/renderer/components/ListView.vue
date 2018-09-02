<template>
<div>
  <el-button @click="addScreen">Add Screen</el-button>
  <el-button @click="saveGenerate" :loading="loading">Save &amp; Generate</el-button>
  <div style="margin-top: 20px;">
    <el-card style="width: 350px; float: left; margin: 10px;"
      :body-style="{ padding: '0px' }"
      v-for="screen in screens.screens" :key="screen.name"
      shadow="hover">
      <div @click="openScreen(screen)" style="text-align: center; cursor: pointer;">
        <img :src="screen.dataurl" style="max-width: 360px; max-height: 200px;">
      </div>
      <div style="padding: 7px;">
        <i v-if="screen.match" class="el-icon-location"></i>
        <span>{{ screen.name }}</span>
        <div style="margin: 7px; float: right;">
          <el-button @click="delScreen(screen)" size="mini" type="danger" icon="el-icon-delete" circle></el-button>
        </div>
      </div>
    </el-card>
    <div style="clear: both;"></div>
  </div>
  <div @dragover.prevent @drop="dropFile"
    style="visibility:hidden; opacity:0" class="dropzone"></div>
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
  data() {
    return {
      loading: false,
    };
  },
  methods: {
    async addScreen(image) {
      const screen = new Screen();
      if (!image) {
        const [imagePath] = this.$electron.remote.dialog.showOpenDialog({
          message: 'select image',
          properties: ['openFile', ],
          filters: [
            { name: 'Images', extensions: ['jpg', 'png', 'gif'] },
          ],
        });
        if (!imagePath) return;
        image = await Jimp.read(imagePath);
      }
      try {
        fs.mkdirSync(path.join(this.path, 'screens'));
      } catch (error) {
        // ignore error
      }
      const filename = `${uuid()}.png`;
      const localPath = path.join(this.path, 'screens', filename);
      await image.writeAsync(localPath);
      screen.image = filename;
      screen.dataurl = await image.getBase64Async('image/png');
      this.screens.add(screen);
      this.$emit('open', screen);
    },
    async dropFile(ev) {
      ev.stopPropagation();
      ev.preventDefault();
      const file = ev.dataTransfer.files[0];
      const fileReader = new FileReader();
      fileReader.readAsArrayBuffer(file);
      const buffer = await new Promise(r => fileReader.addEventListener("load", r));
      const image = await Jimp.read(buffer.target.result);
      return this.addScreen(image);
    },
    delScreen(screen) {
      this.screens.del(screen);
    },
    openScreen(screen) {
      this.$emit('open', screen);
    },
    async saveGenerate() {
      this.loading = true;
      await this.screens.save();
      await this.screens.generate();
      await this.screens.save();
      this.loading = false;
    },
  },
}

var lastTarget = null;

window.addEventListener("dragenter", function(e)
{
    lastTarget = e.target; // cache the last target here
    // unhide our dropzone overlay
    document.querySelector(".dropzone").style.visibility = "";
    document.querySelector(".dropzone").style.opacity = 1;
});

window.addEventListener("dragleave", function(e)
{
    // this is the magic part. when leaving the window,
    // e.target happens to be exactly what we want: what we cached
    // at the start, the dropzone we dragged into.
    // so..if dragleave target matches our cache, we hide the dropzone.
    if(e.target === lastTarget || e.target === document)
    {
        document.querySelector(".dropzone").style.visibility = "hidden";
        document.querySelector(".dropzone").style.opacity = 0;
    }
});
</script>

<style lang="scss" scoped>
div.dropzone
{
  position: fixed; top: 0; left: 0; 
  z-index: 9999999999;               
  width: 100%; height: 100%;         
  background-color: rgba(0,0,0,0.5);
  transition: visibility 175ms, opacity 175ms;
}
</style>

