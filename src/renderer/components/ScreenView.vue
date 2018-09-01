<template>
  <div>
    <el-input v-model="screen.name" placeholder="name"></el-input>

    <input type="file" v-if="!image" value="Select Image" @change="uploadImage($event)">
    <canvas id="c" width="960" height="540"></canvas>

    <el-button type="primary">Add Hotspot</el-button>
    <el-button type="primary">Add Detect Zone</el-button>
  </div>
</template>

<script> 
import { fabric } from 'fabric';
export default {
  data() {
    return {
      image: null,
      canvas: null,
    };
  },
  name: 'screen-view',
  props: ['screen'],
  methods: {
    async uploadImage(e) {
      this.canvas = new fabric.Canvas('c');
      const reader = new FileReader();
      reader.onload = (event) => {
        const image = new Image();
        image.src = event.target.result;
        image.onload = () => {
          this.image = new fabric.Image(image, {
            selectable: false,
          });
          this.canvas.setWidth(this.image.width);
          this.canvas.setHeight(this.image.height);
          this.canvas.add(this.image);
          this.canvas.renderAll();
        }
      }
      reader.readAsDataURL(e.target.files[0]);
    },
  },
}
</script>

