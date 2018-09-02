<template>
  <div id="app">
    <list-view v-if="screens && !screen" :screens="screens" :path="path" @open="openScreen"></list-view>
    <screen-view v-if="screens && screen" :screens="screens" :screen="screen" :path="path" @save="saveScreen"></screen-view>
  </div>
</template>

<script>
import fs from 'fs';
import Jimp from 'jimp';
import path from 'path';
import ListView from '@/components/ListView'
import ScreenView from '@/components/ScreenView'
import { Screens } from "./Screen";

export default {
  name: 'ankulua-vision',
  components: {
    ListView,
    ScreenView,
  },
  data() {
    return {
      path: null,
      screens: null,
      screen: null,
    };
  },
  async mounted() {
    while (!this.path) {
      [this.path] = this.$electron.remote.dialog.showOpenDialog({
        message: 'working path',
        properties: ['openDirectory', 'createDirectory'],
      });
    }
    this.screens = new Screens(this.path);
    return this.screens.load();
  },
  methods: {
    openScreen(screen) {
      this.screen = screen;
    },
    saveScreen(screen) {
      this.screen = null;
    },
  },
}
</script>

<style>
  /* CSS */
</style>
