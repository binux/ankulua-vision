<template>
  <div>
    <el-button @click="$emit('save', screen)" :disabled="!screen.name">Save</el-button>
    <el-container>
      <el-main ref="main">
        <el-input v-model="screen.name" placeholder="name" ref="nameInput"></el-input>
        <canvas id="c"></canvas>
      </el-main>

      <el-aside width="300px" style="padding: 20px 10px 10px 20px;">
        <p>
          <el-switch v-model="screen.match" active-text="Match Screen"></el-switch>
        </p>
        <p>
          <el-button type="primary" @click="adding='hotspot'">Add Hotspot</el-button>
        </p>
        <p>
          <el-button type="primary" @click="adding='detectZone'">Add Detect Zone</el-button>
        </p>
        <div v-if="editing && editing.type == 'hotspot'">
          <h2>Hotspot</h2>
          <img style="max-width: 300px" :src="image.toDataURL({ left: this.editing.left, top: this.editing.top, width: this.editing.width, height: this.editing.height })">
          <br />
          <el-select v-model="editing.next" multiple allow-create filterable placeholder="name">
            <el-option label="[prev-screen]" value="[prev-screen]"></el-option>
            <el-option label="[next-screen]" value="[next-screen]"></el-option>
            <el-option v-for="s in screens.screens" :key="s.name" :label="s.name" :value="s.name"></el-option>
          </el-select>
          <pre>{{ JSON.stringify(editing, null, 2) }}</pre>
          <el-button type="danger" @click="delHotspot(editing)">Delete</el-button>
        </div>
        <div v-else-if="editing && editing.type == 'detectZone'">
          <h2>Detection Zone</h2>
          <img style="max-width: 300px" :src="image.toDataURL({ left: this.editing.left, top: this.editing.top, width: this.editing.width, height: this.editing.height })">
          <p>
            similarly: {{ editing.similarly }} <br />
            <el-slider :min="0" :max="1" :step="0.05" v-model="editing.similarly"></el-slider>
          </p>
          <p>
            search range: {{ editing.range }} <br />
            <el-slider :min="0" :max="image.width" v-model="editing.range"></el-slider>
          </p>
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
      rangeBox: null,
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
    editing() {
      if (this.editing && this.editing.type == 'detectZone' && !this.rangeBox) {
        this.rangeBox = new fabric.Rect({
          left: this.editing.left - this.editing.range / 2,
          top: this.editing.top - this.editing.range / 2,
          width: this.editing.width + this.editing.range,
          height: this.editing.height + this.editing.range,
          fill: 'white',
          opacity: 0.2,
          stroke: 'orange',
          strokeWidth: 2,
          selectable: false,
        });
        this.canvas.add(this.rangeBox);
      }
    },
    'editing.next': function() {
      if (this.editing && this.editing.rect && this.editing.type == 'hotspot') {
        for (const o of this.editing.rect.getObjects()) {
          o.set('text', this.editing.name);
          o.canvas.renderAll();
        }
      }
    },
    'editing.range': function() {
      if (this.rangeBox && this.editing && this.editing.type == 'detectZone') {
        this.rangeBox.set({
          left: this.editing.left - this.editing.range / 2,
          top: this.editing.top - this.editing.range / 2,
          width: this.editing.width + this.editing.range,
          height: this.editing.height + this.editing.range,
        });
        this.canvas.renderAll();
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
        fill: '#a9a9a9',
        fontStyle: 'bold',
        fontFamily: 'arial',
        originX: 'center',
        originY: 'center'
      });
      const group = new fabric.Group([rect, text], {
        opacity: 0.7,
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
      this.editing = hotspot;
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
        opacity: 0.7,
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
      this.editing = detectZone;
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
          left: Math.max(0, Math.min(startPointer.x, pointer.x)),
          top: Math.max(0, Math.min(startPointer.y, pointer.y)),
          width: Math.abs(startPointer.x - pointer.x),
          height: Math.abs(startPointer.y - pointer.y),
        }
        const zoom = this.canvas.getZoom();
        opt.width = Math.min(this.canvas.width / zoom - opt.left, opt.width);
        opt.height = Math.min(this.canvas.height / zoom - opt.top, opt.height);
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
        if (this.rangeBox) {
          this.canvas.remove(this.rangeBox)
          this.rangeBox = null;
        }
      });
    },
    async openImage() {
      this.initCanvas();
      this.image = await new Promise(r => {
        fabric.Image.fromURL(this.screen.dataurl, r);
      });
      const ratio = Math.min(this.$refs.nameInput.$el.clientWidth / this.image.width, (window.innerHeight - 100) / this.image.height);
      this.canvas.setZoom(ratio);
      this.canvas.setWidth(this.image.width * ratio);
      this.canvas.setHeight(this.image.height * ratio);
      this.canvas.setBackgroundImage(this.image);
      this.canvas.renderAll();
      this.screen.detectZones.forEach(o => this.addDetectZone(o));
      this.screen.hotspots.forEach(o => this.addHotspot(o));
      this.canvas.discardActiveObject();
      this.canvas.requestRenderAll();
      this.editing = null;
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
