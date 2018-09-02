<template>
  <div>
    <el-container>
      <el-main ref="main">
        <el-input v-model="screen.name" placeholder="name" ref="nameInput"></el-input>
        <canvas id="c"></canvas>
      </el-main>

      <el-aside width="200" style="padding-top: 20px;">
        <p>
          <el-switch v-model="screen.match" active-text="Match Screen"></el-switch>
        </p>
        <p>
          <el-button type="primary" @click="adding='hotspot'">Add Hotspot</el-button>
        </p>
        <p>
          <el-button type="primary" @click="adding='detectZone'">Add Detect Zone</el-button>
        </p>
        <div v-if="editing && editing.name">
          <h2>Hotspot</h2>
          <img style="max-width: 200px" :src="image.toDataURL({ left: this.editing.left, top: this.editing.top, width: this.editing.width, height: this.editing.height })">
          <br />
          <el-select v-model="editing.name" filterable placeholder="name">
            <el-option label="[prev-screen]" value="[prev-screen]"></el-option>
            <el-option label="[next-screen]" value="[next-screen]"></el-option>
            <el-option v-for="s in screens" :key="s.name" :label="s.name" :value="s.name"></el-option>
          </el-select>
          <pre>{{ JSON.stringify(editing, null, 2) }}</pre>
          <el-button type="danger" @click="delHotspot(editing)">Delete</el-button>
        </div>
        <div v-else-if="editing">
          <h2>Detection Zone</h2>
          <img style="max-width: 200px" :src="image.toDataURL({ left: this.editing.left, top: this.editing.top, width: this.editing.width, height: this.editing.height })">
          <pre>{{ JSON.stringify(editing, null, 2) }}</pre>
          <el-button type="danger" @click="delDetectZone(editing)">Delete</el-button>
        </div>
      </el-aside>
    </el-container>
  </div>
</template>

<script> 
import fs from 'fs';
import { fabric } from 'fabric';
import { Hotspot, DetectZone } from '../Screen';

function syncRectAndObj(rect, obj) {
  rect.on('moving', o => {
    const g = o.target;
    obj.width = g.width * g.scaleX;
    obj.height = g.height * g.scaleY;
    obj.left = g.left;
    obj.top = g.top;
  });
  rect.on('scaling', o => {
    const g = o.target;
    obj.width = g.width * g.scaleX;
    obj.height = g.height * g.scaleY;
    obj.left = g.left;
    obj.top = g.top;
  });
}

export default {
  data() {
    return {
      image: null,
      canvas: null,
      adding: null,
      editing: null,
    };
  },
  name: 'screen-view',
  props: ['screen', 'screens'],
  watch: {
    adding(value) {
      if (value) {
        this.canvas.defaultCursor = 'crosshair';
      } else {
        this.canvas.defaultCursor = 'default';
      }
    },
  },
  async mounted() {
    await this.openImage();
  },
  methods: {
    addHotspot(hotspot) {
      const rect = new fabric.Rect({
        left: hotspot.left,
        top: hotspot.top,
        width: hotspot.width,
        height: hotspot.height,
        lockRotation: true,
        fill: 'blue',
      });
      const text = new fabric.Text(hotspot.name, {
        left: hotspot.left + hotspot.width / 2,
        top: hotspot.top + hotspot.height / 2,
        width: hotspot.width,
        height: hotspot.height,
        fontSize: 24,
        fill: 'gray',
        fontFamily: 'arial',
        originX: 'center',
        originY: 'center'
      });
      const group = new fabric.Group([rect, text], {
        opacity: 0.4,
      });
      group.setControlsVisibility({
        mtr: false,
      });
      group.on('selected', o => {
        this.editing = hotspot;
      });
      syncRectAndObj(group, hotspot);
      hotspot.rect = group;
      this.canvas.add(group);
      this.canvas.setActiveObject(group);
      this.screen.addHotspot(hotspot);
    },
    delHotspot(hotspot) {
      this.screen.delHotspot(hotspot);
      if (hotspot.rect) {
        this.canvas.remove(hotspot.rect);
        hotspot.rect = null;
      }
    },
    addDetectZone(detectZone) {
      const rect = new fabric.Rect({
        left: detectZone.left,
        top: detectZone.top,
        width: detectZone.width,
        height: detectZone.height,
        lockRotation: true,
        fill: 'orange',
        opacity: 0.3,
      });
      rect.setControlsVisibility({
        mtr: false,
      });
      rect.on('selected', o => {
        this.editing = detectZone;
      });
      syncRectAndObj(rect, detectZone);
      detectZone.rect = rect;
      this.canvas.add(rect);
      this.canvas.setActiveObject(rect);
      this.screen.addDetectZone(detectZone);
    },
    delDetectZone(detectZone) {
      this.screen.delDetectZone(detectZone);
      if (detectZone.rect) {
        this.canvas.remove(detectZone.rect);
        detectZone.rect = null;
      }
    },
    initCanvas() {
      this.canvas = new fabric.Canvas('c');
      let startPointer = null;
      this.canvas.on('mouse:down', o => {
        if (!this.adding) return;
        startPointer = this.canvas.getPointer(o.e);
      });
      this.canvas.on('mouse:up', o => {
        if (!this.adding || !startPointer) return;
        const pointer = this.canvas.getPointer(o.e);
        const opt = {
          left: Math.min(startPointer.x, pointer.x),
          top: Math.min(startPointer.y, pointer.y),
          width: Math.abs(startPointer.x - pointer.x),
          height: Math.abs(startPointer.y - pointer.y),
        }
        if (this.adding === 'hotspot') {
          const hotspot = new Hotspot(opt);
          this.addHotspot(hotspot);
        } else {
          const detectZone = new DetectZone(opt);
          this.addDetectZone(detectZone);
        }
        startPointer = null;
        this.adding = null;
      });
      this.canvas.on('object:moving', o => {
        const obj = o.target;
        const zoom = obj.canvas.getZoom();
        const rect = obj.getBoundingRect();
        // if object is too big ignore
        if(rect.height > obj.canvas.height || rect.width > obj.canvas.width) {
          return;
        }
        obj.setCoords();
        // top-left  corner
        if(rect.top < 0 || rect.left < 0){
          obj.top = Math.max(obj.top, 0);
          obj.left = Math.max(obj.left, 0);
        }
        // bot-right corner
        if(rect.top + rect.height  > obj.canvas.height || rect.left + rect.width  > obj.canvas.width) {
          obj.top = Math.min(obj.top, (obj.canvas.height - rect.height) / zoom);
          obj.left = Math.min(obj.left, (obj.canvas.width - rect.width) / zoom);
        }
      });
      this.canvas.on('selection:cleared', o => {
        this.editing = null;
      });
    },
    async openImage() {
      this.initCanvas();
      this.image = await new Promise(r => {
        fabric.Image.fromURL(this.screen.dataurl, r);
      });
      const ratio = Math.min(this.$refs.nameInput.$el.offsetWidth / this.image.width, (window.innerHeight - 100) / this.image.height);
      this.canvas.setZoom(ratio);
      this.canvas.setWidth(this.image.width * ratio);
      this.canvas.setHeight(this.image.height * ratio);
      this.canvas.setBackgroundImage(this.image);
      this.canvas.renderAll();
    },
  },
}
</script>

<style lang="scss" scoped>
#c {
  border: 1px solid red;
}
p {
  margin-top: 10px;
}
</style>
