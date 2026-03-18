export type BatteryCommand =
  | { kind: 'poll-once' }
  | { kind: 'loop' }
  | { kind: 'login' };

export function parseBatteryCommand(argv: string[]): BatteryCommand {
  if (argv.includes('--loop')) return { kind: 'loop' };
  if (argv[0] === 'login') return { kind: 'login' };
  return { kind: 'poll-once' };
}
