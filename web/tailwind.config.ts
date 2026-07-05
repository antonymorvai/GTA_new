import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        surface: '#12151e',
        panel: '#1a1e2a',
        accent: '#4f8cff',
      },
    },
  },
  plugins: [],
};

export default config;
