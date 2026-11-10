export const player = {
  "behavior": [
    "scripts/humanoid-locomotion.js",
    "scripts/player.js",
    "scripts/merge-input.js"
  ],
  "feetPosition": {
    "x": 0,
    "y": 0.5,
    "z": 2.8
  },
  "physics": {
    "body": "character"
  },
  "tags": [
    "player"
  ],
  "platformState": [
    "merge"
  ],
  "state": {
    "merge": null,
    "mergeSelected": -1,
    "mergeBoardOpen": false
  }
};
