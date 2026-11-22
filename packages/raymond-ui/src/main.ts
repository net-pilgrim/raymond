import { mount } from 'svelte';
import './app.css';
import App from './App.svelte';

const app = mount(App as any, {
  target: document.getElementById('app')!,
} as any);

export default app;
