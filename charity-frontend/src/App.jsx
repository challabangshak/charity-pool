
import './App.css';
import * as MicroStacks from '@micro-stacks/react';
import Home from './pages/Home.jsx';

import React from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";

// import Home from "./pages/Home.jsx"; 
// import About from "./About";
// import Donate from "./Donate";
// import Leaderboard from "./Leaderboard";
// import Contact from "./Contact";

export default function App () {
  return (
    <MicroStacks.ClientProvider
      appName={'React + micro-stacks'}
      appIconUrl={"reactLogo"}
    >
      {/* <Contents /> */}
      <BrowserRouter>
      <div className="bg-gray-100 min-h-screen">
        <Routes>
          <Route path="/" element={<Home />} />
        </Routes>
      </div>
    </BrowserRouter>
    </MicroStacks.ClientProvider>

  );
};