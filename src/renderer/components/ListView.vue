<template>
<div>
  <el-button @click="addScreen">Add Screen</el-button>
  <el-button>Save &amp; Generate</el-button>
</div>
</template>

<script>
import { Screen } from "../Screen";
export default {
  name: 'list-view',
  methods: {
    addScreen() {
      const screen = new Screen();
      this.$emit('open', screen);
    },
  },
}
</script>

