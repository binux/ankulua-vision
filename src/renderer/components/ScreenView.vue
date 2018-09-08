<template>
  <div>
    <el-button @click="$emit('save', screen)" :disabled="!screen.name || screenNames.indexOf(screen.name) !== -1">Save</el-button>
    <span v-if="!screen.name">need screen name</span>
    <span v-if="screen.name && screenNames.indexOf(screen.name) !== -1">duplicate name</span>
    <el-button v-if="history.length" @click="history.pop();jumpTo(history.pop())">&lt;</el-button>

    <el-dialog title="Select Screen" v-if="selectScreenDialog && editing && editing.type === 'hotspot' && (editing.next.length > 1 || editing.next[0] === '[any]')" :visible="true">
      <el-button v-for="next in nextFilter(editing.next)" :key="next" @click="jumpTo(next)">{{ next }}</el-button>
    </el-dialog>

    <el-container>
      <el-main ref="main">
        <el-autocomplete v-model="screen.name" placeholder="name" :fetch-suggestions="nameSuggest"></el-autocomplete>
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
            <el-option label="[any]" value="[any]"></el-option>
            <el-option label="[prev-screen]" value="[prev-screen]"></el-option>
            <el-option label="[next-screen]" value="[next-screen]"></el-option>
            <el-option v-for="name in screenNames" :key="name" :label="name" :value="name"></el-option>
            <el-option v-for="name in newScreenNames" :key="name" :label="name" :value="name"></el-option>
          </el-select>
        </div>
        <div v-else-if="editing && editing.type == 'detectZone'">
          <h2>Detection Zone</h2>
          <img style="max-width: 300px" :src="image.toDataURL({ left: this.editing.left, top: this.editing.top, width: this.editing.width, height: this.editing.height })">
        </div>
        <div v-if="editing">
          <p>
            similarity: <el-input size="mini" v-model.number="editing.similarity" style="width: 55px"></el-input>  <br />
            <el-slider :min="0" :max="1" :step="0.05" v-model="editing.similarity"></el-slider>
          </p>
          <p>
            search range: <el-input size="mini" v-model.number="editing.range" style="width: 70px"></el-input>  <br />
            <el-slider :min="0" :max="image.width * 2" v-model="editing.range"></el-slider>
          </p>
          <p>
            timeout: <el-input size="mini" v-model.number="editing.timeout" style="width: 70px"></el-input>  <br />
            <el-slider :min="1" :max="300" v-model="editing.timeout"></el-slider>
          </p>
          <pre>{{ JSON.stringify(editing, null, 2) }}</pre>
          <el-button type="danger" @click="del(editing)">Delete</el-button>
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
      selectScreenDialog: false,

      history: [],
      screenNames: [],
      newScreenNames: [],
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
      if (this.canvas && this.editing && !this.rangeBox) {
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
      if (this.canvas && this.editing && this.editing.rect && this.editing.type == 'hotspot') {
        for (const o of this.editing.rect.getObjects()) {
          o.set('text', this.editing.name);
          o.canvas.renderAll();
        }
      }
    },
    'editing.range': function() {
      if (this.canvas && this.rangeBox && this.editing) {
        this.rangeBox.set({
          left: this.editing.left - this.editing.range / 2,
          top: this.editing.top - this.editing.range / 2,
          width: this.editing.width + this.editing.range,
          height: this.editing.height + this.editing.range,
        });
        this.canvas.renderAll();
      }
    },
    'screen': async function() {
      this.image = null;
      this.editing = null;
      this.adding = null,
      this.editing = null,
      this.rangeBox = null,
      await this.initNames();
      await this.openImage();
    },
  },
  async mounted() {
    await this.initNames();
    await this.initCanvas();
    await this.openImage();
  },
  methods: {
    async initNames() {
      const seenNames = new Set();
      const newNames = new Set();
      for (const screen of this.screens.screens) {
        if (screen === this.screen) continue;
        if (!screen.name) continue;
        seenNames.add(screen.name);
        for (const hotspot of screen.hotspots) {
          for (const next of hotspot.next) {
            if (!next) continue;
            if (next.startsWith('[')) continue;
            newNames.add(next)
          }
        }
      }
      this.newScreenNames = [...newNames].filter(x => !seenNames.has(x));
      this.screenNames = [...seenNames];
    },
    nextFilter(nexts) {
      const result = new Set();
      for (const n of nexts) {
        if (n === '[any]') {
          this.screens.screens
            .filter(s => s.match == true)
            .forEach(s => result.add(s.name));
        } else if (n.startsWith('[') && n.endsWith(']')) {
          result.add(n);
        } else if (this.screenNames.includes(n)) {
          result.add(n);
        }
      }
      return [...result].sort();
    },
    jumpTo(name) {
      let jumpTo;
      this.selectScreenDialog = false;
      for (let i = 0; i < this.screens.screens.length; i++) {
        const screen = this.screens.screens[i]
        if (name === '[next-screen]' && screen === this.screen) {
          jumpTo = this.screens.screens[i+1];
          break;
        } else if (name === '[prev-screen]' && screen === this.screen) {
          jumpTo = this.screens.screens[i-1];
          break;
        } else if (screen.name == name) {
          jumpTo = screen;
        }
      }
      if (jumpTo) {
        this.canvas.clear();
        return this.$emit('open', jumpTo);
      } else {
        this.$message({
          message: `Cannot find screen ${name}.`,
          type: 'warning'
        });
      }
    },
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
      group.on('mousedblclick', o => {
        if (hotspot.next.length == 0) {
          this.$message({
            message: 'No screen defined.',
            type: 'warning'
          });
          this.editing = hotspot;
        } else if (hotspot.next.length == 1 && hotspot.next[0] !== '[any]') {
          this.jumpTo(hotspot.next[0]);
        } else {
          this.selectScreenDialog = true;
          this.editing = hotspot;
        }
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
    del(zone) {
      if (zone.type === 'hotspot') {
        this.delHotspot(zone);
      } else if (zone.type === 'detectZone') {
        this.delDetectZone(zone)
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
      if (this.history[this.history.length - 1] !== this.screen.name) {
        this.history.push(this.screen.name);
      }
      this.image = await new Promise(r => {
        fabric.Image.fromURL(this.screen.dataurl, r);
      });
      const ratio = Math.min((this.$refs.main.$el.clientWidth - 40) / this.image.width, (window.innerHeight - 100) / this.image.height);
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
    nameSuggest(queryString, cb) {
      const result = queryString ? this.newScreenNames.filter(x => x.toLowerCase().indexOf(queryString.toLowerCase()) === 0) : this.newScreenNames;
      cb(result.map(x => ({ value: x })));
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
.el-autocomplete {
  display: block;
}
</style>
