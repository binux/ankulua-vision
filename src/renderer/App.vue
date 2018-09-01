<template>
  <div id="app">
    <list-view v-if="!screen" :screens="screens" @open="openScreen"></list-view>
    <screen-view v-if="screen" :screen="screen" @save="saveScreen"></screen-view>
  </div>
</template>

<script>
  import ListView from '@/components/ListView'
  import ScreenView from '@/components/ScreenView'

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
    created() {
      while (!this.path) {
        [this.path] = this.$electron.remote.dialog.showOpenDialog({
          message: 'working path',
          properties: ['openDirectory', ],
        });
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
