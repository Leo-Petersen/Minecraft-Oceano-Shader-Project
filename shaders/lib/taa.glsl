//Thanks to CaptTatsu on helping me implement TAA back when my frontal lobe was underdeveloped

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D colortex7;
uniform sampler2D depthtex1;

//Previous frame reprojection from Chocapic13
vec2 reprojection(vec3 pos){
		vec4 fragpositionPrev = gbufferProjectionInverse * vec4(pos*2.0-1.0,1.);
		fragpositionPrev /= fragpositionPrev.w;
		
		fragpositionPrev = gbufferModelViewInverse * fragpositionPrev;

		vec4 previousPosition = fragpositionPrev + vec4(cameraPosition-previousCameraPosition,0.0)*float(pos.z > 0.56);
		previousPosition = gbufferPreviousModelView * previousPosition;
		previousPosition = gbufferPreviousProjection * previousPosition;
		return previousPosition.xy/previousPosition.w*0.5+0.5;
}

void main(){
    vec3 color = texture2DLod(colortex0,texcoord.xy,0).rgb;
    float temp = texture2DLod(colortex7,texcoord.xy,0).r;
    
    float depth = texture2DLod(depthtex1,texcoord.xy,0).r;
    vec2 prvcoord = reprojection(vec3(texcoord.xy, depth));
    vec3 tempcolor = texture2DLod(colortex7,prvcoord.xy,0).gba;
    
    vec2 view = 1.0/vec2(viewWidth,viewHeight);
    
    vec3 coltl = texture2DLod(colortex0,texcoord.xy+vec2(-1.0,-1.0)*view,0).rgb;
    vec3 coltm = texture2DLod(colortex0,texcoord.xy+vec2( 0.0,-1.0)*view,0).rgb;
    vec3 coltr = texture2DLod(colortex0,texcoord.xy+vec2( 1.0,-1.0)*view,0).rgb;
    vec3 colml = texture2DLod(colortex0,texcoord.xy+vec2(-1.0, 0.0)*view,0).rgb;
    vec3 colmr = texture2DLod(colortex0,texcoord.xy+vec2( 1.0, 0.0)*view,0).rgb;
    vec3 colbl = texture2DLod(colortex0,texcoord.xy+vec2(-1.0, 1.0)*view,0).rgb;
    vec3 colbm = texture2DLod(colortex0,texcoord.xy+vec2( 0.0, 1.0)*view,0).rgb;
    vec3 colbr = texture2DLod(colortex0,texcoord.xy+vec2( 1.0, 1.0)*view,0).rgb;
    
    vec3 minclr = min(color,min(min(min(coltl,coltm),min(coltr,colml)),min(min(colmr,colbl),min(colbm,colbr))));
    vec3 maxclr = max(color,max(max(max(coltl,coltm),max(coltr,colml)),max(max(colmr,colbl),max(colbm,colbr))));
    
    tempcolor = clamp(tempcolor,minclr,maxclr);
    
    // Check if reprojection is valid
    bool validReproj = prvcoord.x > 0.0 && prvcoord.x < 1.0 && prvcoord.y > 0.0 && prvcoord.y < 1.0;
    
    vec2 velocity = (texcoord.xy-prvcoord.xy)/view;
    float blendfactor = clamp(1.0 - sqrt(length(velocity))*0.5, 0.0, 1.0) * 0.4 + 0.4;
    
    blendfactor *= float(validReproj);
    
    if(depth > 0.56){
        color = mix(color, tempcolor, blendfactor);
    }
    
    tempcolor = color;
    
/* DRAWBUFFERS:07 */
    gl_FragData[0] = vec4(color,1.0);
    gl_FragData[1] = vec4(temp,tempcolor);
}
