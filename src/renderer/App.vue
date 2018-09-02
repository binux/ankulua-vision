<template>
  <div id="app">
    <list-view v-if="!screen" :screens="screens" :path="path" @open="openScreen"></list-view>
    <screen-view v-if="screen" :screens="screens" :screen="screen" :path="path" @save="saveScreen"></screen-view>
  </div>
</template>

<script>
import fs from 'fs';
import Jimp from 'jimp';
import path from 'path';
import ListView from '@/components/ListView'
import ScreenView from '@/components/ScreenView'
import { Screen } from "./Screen";

export default {
  name: 'ankulua-vision',
  components: {
    ListView,
    ScreenView,
  },
  data() {
    return {
      path: null,
      screens: [],
      screen: null,
    };
  },
  watch: {
    async screens() {
      return new Promise((r, j) => fs.writeFile(
        path.join(this.path, 'meta.json'),
        JSON.stringify({ screens: this.screens }),
        err => err ? j(err) : r(),
      ));
    },
  },
  async mounted() {
    while (!this.path) {
      [this.path] = this.$electron.remote.dialog.showOpenDialog({
        message: 'working path',
        properties: ['openDirectory', 'createDirectory'],
      });
    }
    try {
      const { screens } = JSON.parse(fs.readFileSync(path.join(this.path, 'meta.json')));
      for (const screen of screens) {
        const o = Screen.fromJSON(screen);
        const image = await Jimp.read(screen.image);
        o.dataurl = await image.getBase64Async('image/png');
        this.screens.push(o);
      }
    } catch (err) {
      if (err.code !== 'ENOENT') {
        throw(err);
      }
    }
  },
  methods: {
    openScreen(screen) {
      this.screen = screen;
    },
    saveScreen(screen) {
      if (screen.name && !this.screens.includes(screen)) {
        this.screens.push(screen)
      }
      this.screen = null;
    },
  },
}
</script>

<style>
  /* CSS */
</style>
