Shader "Pya/ReflectionBox"
{
	Properties
	{
		[Header(Display Object)]
		[MaterialToggle] _IsSphere ("Sphere", Float) = 0 
		[MaterialToggle] _IsBox ("Box", Float) = 0
		[MaterialToggle] _IsTorus ("Torus", Float) = 1
		[MaterialToggle] _IsOctahedron ("Octahedron", Float) = 1
		[MaterialToggle] _IsLightBulb ("LightBulb", Float) = 1 

		[Header(Light)]
		_LIntensity("Intensity", Range(0, 10)) = 2.0
		_Bloom("Bloom", Range(0, 10)) = 2.0

		[Header(Bound Flash)]
		[KeywordEnum(None, Sphere, Box, Torus, Octahedron, LightBulb, All)] _Mode("Parent", Float) = 5
		_FIntensity("Intensity", Range(0, 10)) = 4
		_FThreshold("Threshold", Range(0, 1)) = 0.08

		[Header(Environment)]
		[MaterialToggle] _IsPhantom ("Phantom Mode", Float) = 1
		_ColorSpeed("Color Change Speed", Range(0, 10)) = 1
		_Saturation("Saturation", Range(0, 1)) = 0.6
		_RefBoxSize("Reflection Box Size", Vector) =(1,1,1.01)

		[Space (20)]

		[Header(Sphere Setting)]
		_SphereSeed("Seed", Float) = 0
		_SphereSpeed("Speed", Range(0, 1)) = 0.07
		_SphereSize("Size", Float) = 0.1

		[Header(Box Setting)]
		_BoxSeed("Seed", Float) = 10
		_BoxSpeed("Speed", Range(0, 1)) = 0.06
		_BoxSize("Size", Vector) = (0.1,0.1,0.1)

		[Header(Torus Setting)]
		_TorusSeed("Seed", Float) = 50
		_TorusSpeed("Speed", Range(0, 1)) = 0.1
		_TorusRLen("R length", Float) = 0.1
		_TorusrLen("r length", Float) = 0.04

		[Header(Octahedron Setting)]
		_OctahedronSeed("Seed", Float) = 80
		_OctahedronSpeed("Speed", Range(0, 1)) = 0.25
		_OctahedronSize("Size", Float) = 0.1

		[Header(LightBulb Setting)]
		_LightBulbSeed("Seed", Float) = 300
		_LightBulbSpeed("Speed", Range(0, 1)) = 0.3

	}
		SubShader
	{
		Tags { "RenderType" = "Opaque"  "LightMode" = "ForwardBase" }
		LOD 100

		Cull Front

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile _MODE_NONE _MODE_SPHERE _MODE_BOX _MODE_TORUS _MODE_OCTAHEDRON _MODE_LIGHTBULB _MODE_ALL

			#include "UnityCG.cginc"

			#define OBJ_SPHERE 0.0
			#define OBJ_BOX    1.0
			#define OBJ_TORUS  2.0
			#define OBJ_OCTA   3.0
			#define OBJ_BULB   4.0
			#define NO_RENDER  100

			float _IsPhantom;
			float _ColorSpeed;
			float _Saturation;
			float4 _RefBoxSize;
			float _IsSphere;
			float _SphereSeed;
			float _SphereSpeed;
			float _SphereSize;
			float _IsBox;
			float _BoxSeed;
			float _BoxSpeed;
			float4 _BoxSize;
			float _IsTorus;
			float _TorusSeed;
			float _TorusSpeed;
			float _TorusRLen;
			float _TorusrLen;
			float _IsOctahedron;
			float _OctahedronSeed;
			float _OctahedronSpeed;
			float _OctahedronSize;
			float _IsLightBulb;
			float _LightBulbSeed;
			float _LightBulbSpeed;
			float _LIntensity;
			float _Bloom;
			float _FIntensity;
			float _FThreshold;

			//回転行列
			float2x2 rot(float r) {
				float2x2 m = float2x2(cos(r),sin(r),-sin(r),cos(r));
				return m;
			}

			//HSVからRGBへの変換
			float3 hsv(float h, float s, float v) {
				return ((clamp(abs(frac(h+float3(0,2,1)/3.0)*6.0-3.0)-1.0,0.0,1.0)-1.0)*s+1.0)*v;
			}

			//オブジェクトのサイズを取得
			float3 getObjectSize(float obj) {
				//各オブジェクトのサイズを定義(壁反射の計算に使用、距離関数とは別)
				float3 SphereSize = _SphereSize;
				float3 TrousSize = float3(_TorusRLen+_TorusrLen, _TorusRLen+_TorusrLen, _TorusrLen);
				float3 BulbSize = 0.1;
				float3 BoxSize = _BoxSize;
				float3 OctahedronSize = _OctahedronSize;

				//引数で指定されたオブジェクトのサイズを返す
				float3 ObjSize = (obj == OBJ_BOX) ? _BoxSize : (obj == OBJ_TORUS) ? TrousSize : (obj == OBJ_BULB) ? BulbSize : (obj == OBJ_SPHERE) ?  SphereSize : OctahedronSize;

				return ObjSize;
			}

			//三角波 abs(fract(t) - 0.5) * 2.0
			//https://spphire9.wordpress.com/2016/09/10/%E4%B8%80%E5%AE%9A%E5%91%A8%E6%9C%9F%E3%81%AE%E4%B8%89%E8%A7%92%E6%B3%A2/
			float3 triwave(float3 time, float3 len) {
				return abs(frac(time * len) - 0.5) * 2.0 * len - (0.5 * len);
			}

			//壁反射の計算
			float3 reflectbox(float speed, float seed, float obj) {
				float3 time = speed * _Time.y;

				//Seed値だけ時間を経過させる
				time += seed;

				//(壁のサイズ - オブジェクトのサイズ)の範囲でオブジェクトを動かす
				float3 len = _RefBoxSize.xyz - getObjectSize(obj);

				//三角波を生成して壁反射をシミュレート　※オブジェクトの回転考慮していないのでかなりアバウトな反射
				float3 position = triwave(time, len);

				return position;
			}

			//壁の衝突判定をしてFlash値を返す
			float getFlash(float speed, float seed, float obj) {
				//閾値
				float3 threshold = (_RefBoxSize - getObjectSize(obj)) * 0.5 - _FThreshold;
				//オブジェクト座標の取得
				float3 position = reflectbox(speed, seed, obj);
				
				//オブジェクトが壁に近づいたときに衝突したと判定する
				float flash = 0;
				if (abs(position.x) >= threshold.x || abs(position.y) >= threshold.y || abs(position.z) >= threshold.z) {
					flash = _FIntensity * 0.01;
				}

				return flash;
			}

			////////////////////////////////////////////////////////////////
			//  distance functions
			////////////////////////////////////////////////////////////////
			//https://iquilezles.org/www/articles/distfunctions/distfunctions.htm

			//SmoothUnion
			float smin(float a, float b, float k) {
				float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
				return lerp(b, a, h) - k * h * (1.0 - h);
			}

			//Sphere
			float sdSphere(float3 p, float r) {
				return length(p)-r;
			}

			//Box
			float sdBox(float3 p, float3 b) {
				float3 d = abs(p) - b;
				return length(max(d, 0.0));
			}

			//Torus
			float sdTorus(float3 p, float2 t)
			{
			  float2 q = float2(length(p.xz)-t.x,p.y);
			  return length(q)-t.y;
			}

			//Octahedron
			float sdOctahedron(float3 p, float s)
			{
			  p = abs(p);
			  return (p.x+p.y+p.z-s)*0.57735027;
			}

			//Capped Cylinder
			float cylinder(float3 p, float2 h)
			{
				float2 d = abs(float2(length(p.xz) ,p.y)) - float2(h.x, h.y);
				return min(max(d.x,d.y),0.0) + length(max(d,0.0));
			}

			//Light Bulb
			//https://www.shadertoy.com/view/XsXSDl
			float sdUpperBulb(float3 p, float2 h)
			{
				float2 d = abs(float2(length(p.xz) ,p.y)) - float2(h.x*max((1.0-p.y),0.0), h.y);
				return min(max(d.x,d.y),0.0) + length(max(d,0.0));
			}

			float sdLightBulb(float3 p) {
				float d1 = sdUpperBulb(float3(p.x, p.y-0.05, p.z), float2(0.02, 0.03));
				float d2 = sdSphere(p, 0.04);
				float d3 = cylinder(float3(p.x, p.y-0.18, p.z), float2(0.030+0.0031*sin(82.0*p.y*10), 0.035));
				float d4 = sdSphere(float3(p.x, p.y-0.215, p.z), 0.02);
				float dg = smin(d1, d2, 0.23);
				float d = smin(dg, d3, 0.08);
				d = smin(d, d4, 0.01);
				return d;
			}
			////////////////////////////////////////////////////////////////

			float dist(float3 p) {

				float ret;
				float d0, d1, d2, d3, d4;

				///////////Sphereの描画
				if (_IsSphere) {
					float3 p0 = p;
					p0 = p0 - reflectbox(_SphereSpeed, _SphereSeed, OBJ_SPHERE); //壁反射
					d0 = sdSphere(p0, _SphereSize);
				} else {
					d0 = NO_RENDER;
				}

				///////////Boxの描画
				if (_IsBox) {
					float3 p1 = p;
					p1 = p1 - reflectbox(_BoxSpeed, _BoxSeed, OBJ_BOX); //壁反射
					p1.xy = mul(p1.xy, rot(_Time.y*0.5));//回転
					p1.xz = mul(p1.xz, rot(_Time.y*0.5));
					d1 = sdBox(p1, _BoxSize.xyz*0.5);
				} else {
					d1 = NO_RENDER;
				}

				///////////Torusの描画
				if (_IsTorus) {
					float3 p2 = p;
					p2 = p2 - reflectbox(_TorusSpeed, _TorusSeed, OBJ_TORUS);
					p2.xy = mul(p2.xy, rot(_Time.y*0.5));
					p2.xz = mul(p2.xz, rot(_Time.y*0.5));
					d2 = sdTorus(p2, float2(_TorusRLen, _TorusrLen));
				} else {
					d2 = NO_RENDER;
				}

				///////////Torusの描画
				if (_IsOctahedron) {
					float3 p3 = p;
					p3 = p3 - reflectbox(_OctahedronSpeed, _OctahedronSeed, OBJ_OCTA);
					p3.xy = mul(p3.xy, rot(_Time.y*0.5));
					p3.xz = mul(p3.xz, rot(_Time.y*0.5));
					d3 = sdOctahedron(p3, _OctahedronSize);
				} else {
					d3 = NO_RENDER;
				}
				
				///////////LightBulbの描画
				if (_IsLightBulb) {
					float3 p4 = p;
					p4 = p4 - reflectbox(_LightBulbSpeed, _LightBulbSeed, OBJ_BULB);
					p4.xy = mul(p4.xy, rot(_Time.y*0.5));
					p4.xz = mul(p4.xz, rot(_Time.y*0.5));
					d4 = sdLightBulb(p4);
				} else {
					d4 = NO_RENDER;
				}

				ret = smin(d0,  d1, 0.1);
				ret = smin(ret, d2, 0.1);
				ret = smin(ret, d3, 0.1);
				ret = smin(ret, d4, 0.1);

				return ret;
			
			}

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float3 pos: TEXCOORD1;
				float4 vertex : SV_POSITION;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.pos = v.vertex;
				o.uv = v.uv;

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;//レイのスタート地点を設定
				float3 rd = normalize(i.pos.xyz - mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz);//レイの方向を計算

				float d;
				float t = 0.001;
				float acc = 0.0;

				float3 p = float3(0.0, 0.0, 0.0);

				[unroll]
				for (int i = 0; i < 60; ++i) {
					p = ro + rd * t;
					d = dist(p);

					//Phantom Mode
					//https://www.shadertoy.com/view/MtScWW
					d = (_IsPhantom == true) ? max(abs(d), 0.003) : d;
					float a = exp(-d.x*(5/(_Bloom*0.1)));
					acc += a;

					t += d*1.0;
					if (t > 100.0) {break;}
				}

				float flash = 0;

				//壁にオブジェクトが衝突した時に光らせる
				#ifdef _MODE_SPHERE
					flash = (_IsSphere == true) ? getFlash(_SphereSpeed, _SphereSeed, OBJ_SPHERE) : 0;
				#elif _MODE_BOX
					flash = (_IsBox == true) ? getFlash(_BoxSpeed, _BoxSeed, OBJ_BOX) : 0;
				#elif _MODE_TORUS
					flash = (_IsTorus == true) ? getFlash(_TorusSpeed, _TorusSeed, OBJ_TORUS) : 0;
				#elif _MODE_OCTAHEDRON
					flash = (_IsOctahedron == true) ? getFlash(_OctahedronSpeed, _OctahedronSeed, OBJ_OCTA) : 0;
				#elif _MODE_LIGHTBULB
					flash = (_IsLightBulb == true) ? getFlash(_LightBulbSpeed, _LightBulbSeed, OBJ_BULB) : 0;
				#elif _MODE_ALL
					float flash0 = (_IsSphere == true) ? getFlash(_SphereSpeed, _SphereSeed, OBJ_SPHERE) : 0;
					float flash1 = (_IsBox == true) ? getFlash(_BoxSpeed, _BoxSeed, OBJ_BOX) : 0;
					float flash2 = (_IsTorus == true) ? getFlash(_TorusSpeed, _TorusSeed, OBJ_TORUS) : 0;
					float flash3 = (_IsOctahedron == true) ? getFlash(_OctahedronSpeed, _OctahedronSeed, OBJ_OCTA) : 0;
					float flash4 = (_IsLightBulb == true) ? getFlash(_LightBulbSpeed, _LightBulbSeed, OBJ_BULB) : 0;
					flash = flash0;
					flash = (flash == 0) ? flash1 : flash;
					flash = (flash == 0) ? flash2 : flash;
					flash = (flash == 0) ? flash3 : flash;
					flash = (flash == 0) ? flash4 : flash;
				#endif

				float3 col;

				//色相(hue) 彩度(saturation) 明度(blightness)
				col = hsv(frac(0.06*_Time.y*_ColorSpeed), _Saturation, acc * (_LIntensity*0.005 + flash));

				return float4(col, 1.0);
			}
			ENDCG
		}
	}
}