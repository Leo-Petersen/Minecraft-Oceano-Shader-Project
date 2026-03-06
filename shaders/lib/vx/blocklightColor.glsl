//// BLOCK LIGHT COLORS ////
vec3 getBlocklightColor(int id) {
    vec3 color = vec3(0.0);
    
    // Torch, Lantern (ID 2)
    if (id == 2) color = vec3(1.0, 0.6, 0.25);
    // Glowstone (ID 3)
    else if (id == 3) color = vec3(1.0, 0.85, 0.5);
    // Sea Lantern (ID 4)
    else if (id == 4) color = vec3(0.4, 0.85, 1.0);
    // Lava (ID 5)
    else if (id == 5) color = vec3(1.0, 0.4, 0.05);
    // Fire (ID 6)
    else if (id == 6) color = vec3(1.0, 0.5, 0.1);
    // Redstone Torch (ID 7)
    else if (id == 7) color = vec3(1.0, 0.15, 0.05);
    // Jack o Lantern (ID 8)
    else if (id == 8) color = vec3(1.0, 0.55, 0.15);
    // Furnace (ID 9)
    else if (id == 9) color = vec3(1.0, 0.55, 0.2);
    // Magma Block (ID 10)
    else if (id == 10) color = vec3(1.0, 0.35, 0.05);
    // Soul Fire/Torch (ID 11)
    else if (id == 11) color = vec3(0.15, 0.6, 0.85);
    // Crying Obsidian (ID 12)
    else if (id == 12) color = vec3(0.6, 0.2, 0.9);
    // Redstone (ID 13)
    else if (id == 13) color = vec3(1.0, 0.05, 0.0) * 0.3;
    // End Rod (ID 14)
    else if (id == 14) color = vec3(0.95, 0.9, 1.0);
    // Shroomlight (ID 15)
    else if (id == 15) color = vec3(1.0, 0.65, 0.35);
    // Beacon (ID 16)
    else if (id == 16) color = vec3(0.8, 0.95, 1.0);
    // Froglight Ochre (ID 17)
    else if (id == 17) color = vec3(1.0, 0.7, 0.3);
    // Froglight Verdant (ID 18)
    else if (id == 18) color = vec3(0.5, 0.95, 0.4);
    // Froglight Pearlescent (ID 19)
    else if (id == 19) color = vec3(0.9, 0.6, 0.85);
    // Amethyst (ID 20)
    else if (id == 20) color = vec3(0.7, 0.4, 0.95) * 0.5;
    // Nether Portal (ID 21)
    else if (id == 21) color = vec3(0.5, 0.15, 0.9);
    // End Portal Frame (ID 22)
    else if (id == 22) color = vec3(0.5, 0.15, 0.9) * 0.3;
    
    return color;
}