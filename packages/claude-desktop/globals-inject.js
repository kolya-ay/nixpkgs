global.getNixClaudePath = function() {
  if (process.platform === "linux") {
    const p = process.env.CLAUDE_CODE_PATH;
    if (p) return p;
  }
  return null;
};


global.checkNixClaudeReady = function() {
  if (process.platform === "linux") {
    const p = process.env.CLAUDE_CODE_PATH;
    if (p) {
      re.info(`[CCD] Status: ready (Nix)`, p);
      return Dg.Ready;
    }
  }
  return null;
};
