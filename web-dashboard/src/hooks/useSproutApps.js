// src/hooks/useSproutApps.js
import { useState, useEffect } from 'react';
import localforage from 'localforage';

const STORE_KEY = 'sprout_apps';

export default function useSproutApps() {
  const [apps, setApps] = useState([]);

  useEffect(() => {
    loadApps();
  }, []);

  const loadApps = async () => {
    const saved = await localforage.getItem(STORE_KEY);
    setApps(saved || []);
  };

  const saveApps = async (newApps) => {
    await localforage.setItem(STORE_KEY, newApps);
    setApps(newApps);
  };

  const addApp = (app) => {
    const newApps = [...apps, app];
    saveApps(newApps);
  };

  const deleteApp = (id) => {
    const newApps = apps.filter(a => a.id !== id);
    saveApps(newApps);
  };

  return { apps, addApp, deleteApp };
}