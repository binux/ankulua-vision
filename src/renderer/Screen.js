import fs from 'fs';
import path from 'path';
import Jimp from 'jimp';
import rimraf from 'rimraf';

export class Hotspot {
  static NEXT_SCREEN = '[next-screen]';

  constructor({ name, left, top, width, height, file }) {
    this.type = 'hotspot';
    this._name = name || Hotspot.NEXT_SCREEN;
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
    this.file = file;
  }

  set name(val) {
    this._name = val;
    if (this.rect) {
      for (const o of this.rect.getObjects()) {
        if (o.get('type') == 'text') {
          o.set('text', val);
          o.canvas.renderAll();
        }
      }
    }
  }

  get name() {
    return this._name;
  }

  toJSON() {
    return {
      name: this.name,
      left: this.left,
      top: this.top,
      width: this.width,
      height: this.height,
      file: this.file,
    };
  }

  static fromJSON(json) {
    return new Hotspot(json);
  }
}

export class DetectZone {
  constructor({ left, top, width, height, file }) {
    this.type = 'detectzone';
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
    this.file = file;
  }

  toJSON() {
    return {
      left: this.left,
      top: this.top,
      width: this.width,
      height: this.height,
      file: this.file,
    };
  }

  static fromJSON(json) {
    return new DetectZone(json);
  }
}

export class Screen {
  constructor() {
    this.match = false;
    this.name = null;
    this.image = null;
    this.hotspots = [];
    this.detectZones = [];
  }

  toJSON() {
    return {
      match: this.match,
      name: this.name,
      image: this.image,
      hotspots: this.hotspots,
      detectZones: this.detectZones,
    };
  }

  static fromJSON(json) {
    const obj = new this();
    Object.assign(obj, json);
    obj.hotspots = json.hotspots.map(Hotspot.fromJSON);
    obj.detectZones = json.detectZones.map(DetectZone.fromJSON);
    return obj;
  }

  addHotspot(obj) {
    const index = this.hotspots.indexOf(obj);
    if (index == -1) {
      this.hotspots.push(obj);
    }
  }

  addDetectZone(obj) {
    const index = this.detectZones.indexOf(obj);
    if (index == -1) {
      this.detectZones.push(obj);
    }
  }

  delHotspot(obj) {
    const index = this.hotspots.indexOf(obj);
    if (index > -1) {
      this.hotspots.splice(index, 1);
    }
  }

  delDetectZone(obj) {
    const index = this.detectZones.indexOf(obj);
    if (index > -1) {
      this.detectZones.splice(index, 1);
    }
  }

  async loadDataurl() {
    const image = await Jimp.read(this.image);
    this.dataurl = await image.getBase64Async('image/png');
  }

  async generate(basepath) {
    const image = await Jimp.read(this.image);
    const names = {};
    for (const hotspot of this.hotspots) {
      let file = null;
      if (hotspot.file) {
        file = hotspot.file;
      } else {
        let name = hotspot.name;
        if (name == '[prev-screen]') name = '_b';
        if (name == '[next-screen]') name = '_n';
        file = `btn_${this.name}_${name}.png`;
        let i = 1;
        while (names[file]) {
          file = `btn_${this.name}_${name}_${i++}.png`;
        }
      }
      hotspot.file = file;
      names[file] = 1;

      const img = await image.clone()
      await image.clone()
        .crop(hotspot.left, hotspot.top, hotspot.width, hotspot.height)
        .writeAsync(path.join(basepath, file));
    }
    for (const detectZone of this.detectZones) {
      let file = null;
      if (detectZone.file) {
        file = detectZone.file;
      } else {
        file = `s_${this.name}.png`;
        let i = 1;
        while (names[file]) {
          file = `s_${this.name}_${i++}.png`;
        }
      }
      detectZone.file = file;
      names[file] = 1;

      const img = await image.clone()
      await image.clone()
        .crop(detectZone.left, detectZone.top, detectZone.width, detectZone.height)
        .writeAsync(path.join(basepath, file));
    }
  }
}

export class Screens {
  constructor(path) {
    this.path = path;
    this.screens = [];
  }

  [Symbol.iterator]() {
    return this.screens;
  }

  async load() {
    let screens;
    try {
      screens = JSON.parse(fs.readFileSync(path.join(this.path, 'meta.json'))).screens;
    } catch (err) {
      if (err.code !== 'ENOENT') {
        throw(err);
      }
    }
    for (const screen of screens) {
      const o = Screen.fromJSON(screen);
      await o.loadDataurl();
      this.screens.push(o);
    }
  }

  async save() {
    return new Promise((r, j) => fs.writeFile(
      path.join(this.path, 'meta.json'),
      JSON.stringify({ screens: this.screens }),
      err => err ? j(err) : r(),
    ));
  }

  add(screen) {
    this.screens.push(screen);
  }

  del(screen) {
    const index = this.screens.indexOf(screen);
    if (index > -1) {
      try {
        fs.unlinkSync(screen.image);
      } catch (erro) {
        if (err.code !== 'ENOENT') {
          throw(err);
        }
      }
      this.screens.splice(index, 1);
    }
  }

  async generate() {
    const imagePath = path.join(this.path, 'image');
    try {
      await rimraf(imagePath);
      fs.mkdirSync(imagePath);
    } catch (error) {
      // ignore error
    }
    for (const screen of this.screens) {
      await screen.generate(imagePath);
    }
  }
}