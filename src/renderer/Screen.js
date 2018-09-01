export class Hotspot {
  static fromJSON(json) {
    Object.assign(this, json);
  }
}

export class DetectZone {
  static fromJSON(json) {
    Object.assign(this, json);
  }
}

export class Screen {
  constructor() {
    this.name = null;
    this.image = null;
    this.hotspots = [];
    this.detectZones = [];
  }

  static fromJSON(json) {
    this.name = json.name;
    this.image = json.image;
    this.hotspots = json.hotspots.map(Hotspot.fromJSON);
    this.DetectZones = json.detectZones.map(DetectZone.fromJSON);
  }
}