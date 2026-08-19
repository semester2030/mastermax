/** @type {import('jest').Config} */
module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '.',
  testRegex: '.*\\.spec\\.ts$',
  transform: { '^.+\\.ts$': 'ts-jest' },
  testEnvironment: 'node',
  moduleNameMapper: { '^@app/(.*)$': '<rootDir>/src/$1' },
  setupFiles: ['<rootDir>/test/jest-env.js'],
  testTimeout: 60000,
};
