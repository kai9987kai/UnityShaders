Shader "Multiply"
{
Properties
{
}
SubShader
{
Tags
{
// RenderPipeline: <None>
"RenderType"="Opaque"
"Queue"="Geometry"
"ShaderGraphShader"="true"
}
Pass
{
    // Name: <None>
    Tags
    {
        // LightMode: <None>
    }

    // Render State
    // RenderState: <None>

    // Debug
    // <None>

    // --------------------------------------------------
    // Pass

    HLSLPROGRAM

    // Pragmas
    #pragma vertex vert
#pragma fragment frag

    // DotsInstancingOptions: <None>
    // HybridV1InjectedBuiltinProperties: <None>

    // Keywords
    // PassKeywords: <None>
    // GraphKeywords: <None>

    // Defines
    #define ATTRIBUTES_NEED_TEXCOORD0
    #define VARYINGS_NEED_TEXCOORD0
    /* WARNING: $splice Could not find named fragment 'PassInstancing' */
    #define SHADERPASS SHADERPASS_PREVIEW
#define SHADERGRAPH_PREVIEW 1
    /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */

    // Includes
    /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreInclude' */

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/NormalSurfaceGradient.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariables.hlsl"
#include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariablesFunctions.hlsl"
#include "Packages/com.unity.shadergraph/ShaderGraphLibrary/Functions.hlsl"

    // --------------------------------------------------
    // Structs and Packing

    /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPrePacking' */

    struct Attributes
{
 float3 positionOS : POSITION;
 float4 uv0 : TEXCOORD0;
#if UNITY_ANY_INSTANCING_ENABLED
 uint instanceID : INSTANCEID_SEMANTIC;
#endif
};
struct Varyings
{
 float4 positionCS : SV_POSITION;
 float4 texCoord0;
#if UNITY_ANY_INSTANCING_ENABLED
 uint instanceID : CUSTOM_INSTANCE_ID;
#endif
#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
 FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
#endif
};
struct SurfaceDescriptionInputs
{
 float4 uv0;
 float3 TimeParameters;
};
struct VertexDescriptionInputs
{
};
struct PackedVaryings
{
 float4 positionCS : SV_POSITION;
 float4 interp0 : INTERP0;
#if UNITY_ANY_INSTANCING_ENABLED
 uint instanceID : CUSTOM_INSTANCE_ID;
#endif
#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
 FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
#endif
};

    PackedVaryings PackVaryings (Varyings input)
{
PackedVaryings output;
ZERO_INITIALIZE(PackedVaryings, output);
output.positionCS = input.positionCS;
output.interp0.xyzw =  input.texCoord0;
#if UNITY_ANY_INSTANCING_ENABLED
output.instanceID = input.instanceID;
#endif
#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
output.cullFace = input.cullFace;
#endif
return output;
}

Varyings UnpackVaryings (PackedVaryings input)
{
Varyings output;
output.positionCS = input.positionCS;
output.texCoord0 = input.interp0.xyzw;
#if UNITY_ANY_INSTANCING_ENABLED
output.instanceID = input.instanceID;
#endif
#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
output.cullFace = input.cullFace;
#endif
return output;
}


    // --------------------------------------------------
    // Graph

    // Graph Properties
    CBUFFER_START(UnityPerMaterial)
CBUFFER_END

// Object and Global properties

    // Graph Includes
    // GraphIncludes: <None>

    // -- Property used by ScenePickingPass
    #ifdef SCENEPICKINGPASS
    float4 _SelectionID;
    #endif

    // -- Properties used by SceneSelectionPass
    #ifdef SCENESELECTIONPASS
    int _ObjectId;
    int _PassValue;
    #endif

    // Graph Functions
    
void Unity_Floor_float(float In, out float Out)
{
    Out = floor(In);
}


inline float2 Unity_Voronoi_RandomVector_float (float2 UV, float offset)
{
    float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
    UV = frac(sin(mul(UV, m)));
    return float2(sin(UV.y*+offset)*0.5+0.5, cos(UV.x*offset)*0.5+0.5);
}

void Unity_Voronoi_float(float2 UV, float AngleOffset, float CellDensity, out float Out, out float Cells)
{
    float2 g = floor(UV * CellDensity);
    float2 f = frac(UV * CellDensity);
    float t = 8.0;
    float3 res = float3(8.0, 0.0, 0.0);

    for(int y=-1; y<=1; y++)
    {
        for(int x=-1; x<=1; x++)
        {
            float2 lattice = float2(x,y);
            float2 offset = Unity_Voronoi_RandomVector_float(lattice + g, AngleOffset);
            float d = distance(lattice + offset, f);

            if(d < res.x)
            {
                res = float3(d, offset.x, offset.y);
                Out = res.x;
                Cells = res.y;
            }
        }
    }
}

void Unity_Ellipse_float(float2 UV, float Width, float Height, out float Out)
{
#if defined(SHADER_STAGE_RAY_TRACING)
    Out = saturate((1.0 - length((UV * 2 - 1) / float2(Width, Height))) * 1e7);
#else
    float d = length((UV * 2 - 1) / float2(Width, Height));
    Out = saturate((1 - d) / fwidth(d));
#endif
}


float2 Unity_GradientNoise_Dir_float(float2 p)
{
    // Permutation and hashing used in webgl-nosie goo.gl/pX7HtC
    p = p % 289;
    // need full precision, otherwise half overflows when p > 1
    float x = float(34 * p.x + 1) * p.x % 289 + p.y;
    x = (34 * x + 1) * x % 289;
    x = frac(x / 41) * 2 - 1;
    return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
}

void Unity_GradientNoise_float(float2 UV, float Scale, out float Out)
{
    float2 p = UV * Scale;
    float2 ip = floor(p);
    float2 fp = frac(p);
    float d00 = dot(Unity_GradientNoise_Dir_float(ip), fp);
    float d01 = dot(Unity_GradientNoise_Dir_float(ip + float2(0, 1)), fp - float2(0, 1));
    float d10 = dot(Unity_GradientNoise_Dir_float(ip + float2(1, 0)), fp - float2(1, 0));
    float d11 = dot(Unity_GradientNoise_Dir_float(ip + float2(1, 1)), fp - float2(1, 1));
    fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
    Out = lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x) + 0.5;
}

void Unity_Multiply_float4_float4(float4 A, float4 B, out float4 Out)
{
Out = A * B;
}

    /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreVertex' */

    // Graph Vertex
    // GraphVertex: <None>

    /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreSurface' */

    // Graph Pixel
    struct SurfaceDescription
{
float4 Out;
};

SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
{
SurfaceDescription surface = (SurfaceDescription)0;
float4 _UV_de4437533de24120b6b7cfb9ed21e92c_Out_0 = IN.uv0;
float _Floor_0cc468d8df204cd6be8dd8910a6b42de_Out_1;
Unity_Floor_float(14.05, _Floor_0cc468d8df204cd6be8dd8910a6b42de_Out_1);
float _Voronoi_199858faadc745f386b12f7cb015fecc_Out_3;
float _Voronoi_199858faadc745f386b12f7cb015fecc_Cells_4;
Unity_Voronoi_float((_UV_de4437533de24120b6b7cfb9ed21e92c_Out_0.xy), IN.TimeParameters.x, _Floor_0cc468d8df204cd6be8dd8910a6b42de_Out_1, _Voronoi_199858faadc745f386b12f7cb015fecc_Out_3, _Voronoi_199858faadc745f386b12f7cb015fecc_Cells_4);
float _Ellipse_788c001189f74172ad6f4d61b1c29180_Out_4;
Unity_Ellipse_float((_Voronoi_199858faadc745f386b12f7cb015fecc_Out_3.xx), 0.5, 0.5, _Ellipse_788c001189f74172ad6f4d61b1c29180_Out_4);
float _GradientNoise_b6abdacb35864f64892f93f335c69046_Out_2;
Unity_GradientNoise_float(IN.uv0.xy, 10, _GradientNoise_b6abdacb35864f64892f93f335c69046_Out_2);
float4 Color_748a415ed9d24951aa6b7e31f46c1993 = IsGammaSpace() ? float4(1, 1, 0, 1) : float4(SRGBToLinear(float3(1, 1, 0)), 1);
float4 _Multiply_c4bf5d6ed7fe4911a9ecc2461a0d33d0_Out_2;
Unity_Multiply_float4_float4((_GradientNoise_b6abdacb35864f64892f93f335c69046_Out_2.xxxx), Color_748a415ed9d24951aa6b7e31f46c1993, _Multiply_c4bf5d6ed7fe4911a9ecc2461a0d33d0_Out_2);
float4 _Multiply_b31804c4141043febcd84804c74310ca_Out_2;
Unity_Multiply_float4_float4((_Ellipse_788c001189f74172ad6f4d61b1c29180_Out_4.xxxx), _Multiply_c4bf5d6ed7fe4911a9ecc2461a0d33d0_Out_2, _Multiply_b31804c4141043febcd84804c74310ca_Out_2);
surface.Out = all(isfinite(_Multiply_b31804c4141043febcd84804c74310ca_Out_2)) ? half4(_Multiply_b31804c4141043febcd84804c74310ca_Out_2.x, _Multiply_b31804c4141043febcd84804c74310ca_Out_2.y, _Multiply_b31804c4141043febcd84804c74310ca_Out_2.z, 1.0) : float4(1.0f, 0.0f, 1.0f, 1.0f);
return surface;
}

    // --------------------------------------------------
    // Build Graph Inputs

    SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
{
    SurfaceDescriptionInputs output;
    ZERO_INITIALIZE(SurfaceDescriptionInputs, output);

    /* WARNING: $splice Could not find named fragment 'CustomInterpolatorCopyToSDI' */





    output.uv0 =                                        input.texCoord0;
    output.TimeParameters =                             _TimeParameters.xyz; // This is mainly for LW as HD overwrite this value
#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
#define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN                output.FaceSign =                                   IS_FRONT_VFACE(input.cullFace, true, false);
#else
#define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
#endif
#undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN

    return output;
}

    // --------------------------------------------------
    // Main

    #include "Packages/com.unity.shadergraph/ShaderGraphLibrary/PreviewVaryings.hlsl"
#include "Packages/com.unity.shadergraph/ShaderGraphLibrary/PreviewPass.hlsl"

    ENDHLSL
}
}
CustomEditor "UnityEditor.ShaderGraph.GenericShaderGraphMaterialGUI"
FallBack "Hidden/Shader Graph/FallbackError"
}
