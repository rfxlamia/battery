export function getBatteryPaths(homeDir: string) {
  return {
    rootDir: `${homeDir}/.battery`,
    stateFile: `${homeDir}/.battery/state.json`,
    eventsFile: `${homeDir}/.battery/events.jsonl`,
    accountsFile: `${homeDir}/.battery/accounts.json`,
    tokensDir: `${homeDir}/.battery/tokens`,
  };
}

export type BatteryPaths = ReturnType<typeof getBatteryPaths>;
