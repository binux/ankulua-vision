export class Hotspot {
  static NEXT_SCREEN = '[next-screen]';

  constructor({ name, left, top, width, height }) {
    this.type = 'hotspot';
    this._name = name || Hotspot.NEXT_SCREEN;
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
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
    };
  }

  static fromJSON(json) {
    return new this(json);
  }
}

export class DetectZone {
  constructor({ left, top, width, height }) {
    this.type = 'detectzone';
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
  }

  toJSON() {
    return {
      left: this.left,
      top: this.top,
      width: this.width,
      height: this.height,
    };
  }

  static fromJSON(json) {
    return new this(json);
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
    obj.DetectZones = json.detectZones.map(DetectZone.fromJSON);
    return obj;
  }

  addHotspot(obj) {
    const index = this.hotspots.indexOf(obj);
    if (index == -1)
      this.hotspots.push(obj);
  }

  addDetectZone(obj) {
    const index = this.detectZones.indexOf(obj);
    if (index == -1)
      this.detectZones.push(obj);
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
}