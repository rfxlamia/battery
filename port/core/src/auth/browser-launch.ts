import { spawn } from 'node:child_process';

export interface BrowserLaunchCommand {
  cmd: string;
  args: string[];
}

export function getBrowserLaunchCommand(url: string): BrowserLaunchCommand {
  return { cmd: 'xdg-open', args: [url] };
}

export async function openBrowser(url: string): Promise<void> {
  const { cmd, args } = getBrowserLaunchCommand(url);
  const proc = spawn(cmd, args, { stdio: 'ignore', detached: true });
  proc.unref();
  await new Promise<void>((resolve, reject) => {
    proc.on('error', reject);
    proc.on('spawn', resolve);
  });
}
