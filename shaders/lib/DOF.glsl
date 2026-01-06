		const vec2 dof_offsets[60] = vec2[60]  (  vec2( 0.0000, 0.2500 ),
								vec2( -0.2165, 0.1250 ),
								vec2( -0.2165, -0.1250 ),
								vec2( -0.0000, -0.2500 ),
								vec2( 0.2165, -0.1250 ),
								vec2( 0.2165, 0.1250 ),
								vec2( 0.0000, 0.5000 ),
								vec2( -0.2500, 0.4330 ),
								vec2( -0.4330, 0.2500 ),
								vec2( -0.5000, 0.0000 ),
								vec2( -0.4330, -0.2500 ),
								vec2( -0.2500, -0.4330 ),
								vec2( -0.0000, -0.5000 ),
								vec2( 0.2500, -0.4330 ),
								vec2( 0.4330, -0.2500 ),
								vec2( 0.5000, -0.0000 ),
								vec2( 0.4330, 0.2500 ),
								vec2( 0.2500, 0.4330 ),
								vec2( 0.0000, 0.7500 ),
								vec2( -0.2565, 0.7048 ),
								vec2( -0.4821, 0.5745 ),
								vec2( -0.6495, 0.3750 ),
								vec2( -0.7386, 0.1302 ),
								vec2( -0.7386, -0.1302 ),
								vec2( -0.6495, -0.3750 ),
								vec2( -0.4821, -0.5745 ),
								vec2( -0.2565, -0.7048 ),
								vec2( -0.0000, -0.7500 ),
								vec2( 0.2565, -0.7048 ),
								vec2( 0.4821, -0.5745 ),
								vec2( 0.6495, -0.3750 ),
								vec2( 0.7386, -0.1302 ),
								vec2( 0.7386, 0.1302 ),
								vec2( 0.6495, 0.3750 ),
								vec2( 0.4821, 0.5745 ),
								vec2( 0.2565, 0.7048 ),
								vec2( 0.0000, 1.0000 ),
								vec2( -0.2588, 0.9659 ),
								vec2( -0.5000, 0.8660 ),
								vec2( -0.7071, 0.7071 ),
								vec2( -0.8660, 0.5000 ),
								vec2( -0.9659, 0.2588 ),
								vec2( -1.0000, 0.0000 ),
								vec2( -0.9659, -0.2588 ),
								vec2( -0.8660, -0.5000 ),
								vec2( -0.7071, -0.7071 ),
								vec2( -0.5000, -0.8660 ),
								vec2( -0.2588, -0.9659 ),
								vec2( -0.0000, -1.0000 ),
								vec2( 0.2588, -0.9659 ),
								vec2( 0.5000, -0.8660 ),
								vec2( 0.7071, -0.7071 ),
								vec2( 0.8660, -0.5000 ),
								vec2( 0.9659, -0.2588 ),
								vec2( 1.0000, -0.0000 ),
								vec2( 0.9659, 0.2588 ),
								vec2( 0.8660, 0.5000 ),
								vec2( 0.7071, 0.7071 ),
								vec2( 0.5000, 0.8660 ),
								vec2( 0.2588, 0.9659 ));
    
    vec3 getDOF(inout vec3 color){
        const float focal = Focal;
        float aperture = (35.0 / 6.0) / 1000.0;
        const float sizemult = 50.0;

                    //Calculate pixel Circle of Confusion that will be used for bokeh depth of field
                    float z = texture2D(depthtex2, texcoord.st).x;
                    float focus = centerDepthSmooth;
                    float pcoc = (z-focus)/15 * focal * 10;
                    vec4 sample = vec4(0.0);
                    vec3 bcolor = vec3(0.0);
                    float nb = 0.0;
                    vec2 bcoord = vec2(0.0);

                    for ( int i = 0; i < 60; i++) {
                        sample = texture2D(colortex0, texcoord + dof_offsets[i]*pcoc*vec2(1.0,aspectRatio),abs(pcoc * 125.0));

                        bcolor += pow(sample.rgb, vec3(4.545));
                    }
            color.rgb = pow(bcolor*0.0166666666666667, vec3(0.22002200220022));

        return color;
	}