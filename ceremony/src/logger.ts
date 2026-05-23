/**
 * Simple structured logger wrapping pino.
 *
 * Provides a lightweight logging interface for the ceremony CLI.
 * Uses pino with pino-pretty for development-friendly output.
 */

import pino from 'pino';

/**
 * Create a named logger for a ceremony module.
 * Automatically configured for CLI usage with pretty-printing.
 *
 * @param name - Module name (e.g. 'build', 'verify', 'cid')
 * @returns Pino logger instance
 */
export function createLogger(name: string): pino.Logger {
  return pino({
    name,
    level: process.env.LOG_LEVEL ?? 'info',
    transport: {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'HH:MM:ss',
        ignore: 'pid,hostname',
      },
    },
  });
}
