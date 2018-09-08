import fs from 'fs';
import path from 'path';
import Jimp from 'jimp';
import rimraf from 'rimraf';

export class Hotspot {
  static NEXT_SCREEN = '[next-screen]';

  constructor({ next, left, top, width, height, file, similarity, range, timeout }) {
    this.type = 'hotspot';
    this.next = next || [];
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
    this.file = file;
    this.similarity = similarity !== undefined ? similarity : 0.8;
    this.range = range !== undefined ? range : 10;
    this.timeout = timeout !== undefined ? timeout : 10;
  }

  get name() {
    return this.next.join(' | ') || '[unamed]';
  }

  toJSON() {
    return {
      next: this.next,
      left: this.left,
      top: this.top,
      width: this.width,
      height: this.height,
      file: this.file,
      similarity: this.similarity,
      range: this.range,
      timeout: this.timeout,
    };
  }

  static fromJSON(json) {
    return new Hotspot(json);
  }
}

export class DetectZone {
  constructor({ left, top, width, height, file, similarity, range, timeout }) {
    this.type = 'detectZone';
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
    this.file = file;
    this.similarity = similarity !== undefined ? similarity : 0.8;
    this.range = range !== undefined ? range : 10;
    this.timeout = timeout !== undefined ? timeout : 10;
  }

  toJSON() {
    return {
      left: this.left,
      top: this.top,
      width: this.width,
      height: this.height,
      file: this.file,
      similarity: this.similarity,
      range: this.range,
      timeout: this.timeout,
    };
  }

  static fromJSON(json) {
    return new DetectZone(json);
  }
}

export class Screen {
  constructor() {
    this.match = true;
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
    if (process.env.NODE_ENV === 'development') {
      const image = await Jimp.read(path.join('screens', this.image));
      this.dataurl = await image.getBase64Async('image/png');
    } else {
      this.dataurl = `file://${path.join(process.cwd(), 'screens', this.image)}`;
    }
  }

  async generate(basepath) {
    const image = await Jimp.read(path.join('screens', this.image));
    const names = {};
    for (const hotspot of this.hotspots) {
      let file = null;
      if (hotspot.file) {
        file = hotspot.file;
      } else {
        let name = hotspot.next[0];
        if (!name) name = '';
        if (name == '[any]') name = '_a';
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
    return this.screens.values();
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
    const data = {
      screens: this.screens,
    };
    if (this.screens.length) {
      const image = await new Promise(r => {
        fabric.Image.fromURL(this.screens[0].dataurl, r);
      });
      data.width = image.width;
      data.height = image.height;
    }

    return new Promise((r, j) => fs.writeFile(
      path.join(this.path, 'meta.json'),
      JSON.stringify(data),
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
        fs.unlinkSync(path.join('screens', screen.image));
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
      await new Promise((r, j) => rimraf(imagePath, err => err ? j(err) : r()));
      fs.mkdirSync(imagePath);
    } catch (error) {
      console.log(error);
      // ignore error
    }
    for (const screen of this.screens) {
      await screen.generate(imagePath);
    }
  }
}