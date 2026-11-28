((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,C={
dIQ(d){var x,w,v,u,t=d.a,s=t.b.r
if(s==null){x=t.a
if(x==="[DEFAULT]")C.dtP("No default storage bucket could be found. Ensure you have correctly followed the Getting Started guide.")
else C.dtP("No storage bucket could be found for the app '"+x+"'. Ensure you have set the [storageBucket] on [FirebaseOptions] whilst initializing the secondary Firebase app.")}s.toString
if(B.d.aN(s,"gs://"))w=B.d.k_(s,"gs://","")
else w=s
t=t.a
v=t+"|"+w
if($.dak.ar(v)){t=$.dak.h(0,v)
t.toString
return t}u=new C.T7(d,w,t,"plugins.flutter.io/firebase_storage")
$.dak.j(0,v,u)
return u},
dtP(d){throw A.r(A.dII("no-bucket",d,"firebase_storage",null))},
a8e(d,e){A.H(e,$.d80(),!0)
return new C.a8d(e,d)},
bEq(d,e){A.H(e,$.a_P(),!0)
return new C.zw(e,d)},
T7:function T7(d,e,f,g){var _=this
_.c=null
_.d=d
_.e=e
_.a=f
_.b=g},
a8d:function a8d(d,e){this.a=d
this.b=e},
aAa:function aAa(){},
bEt:function bEt(d,e,f){this.a=d
this.b=e
this.c=f},
bEu:function bEu(d){this.a=d},
aAU:function aAU(d,e){this.a=d
this.b=e},
zw:function zw(d,e){this.a=d
this.b=e},
dL5(d){return new C.U_(d.a,d.b,d.c,d.d,d.e,d.f)},
a5W:function a5W(d,e,f,g,h){var _=this
_.e=d
_.f=e
_.r=f
_.a=g
_.b=h},
dmK(d,e){var x=A.dbS(e),w=$.d80()
x=new C.aug(x,d)
$.e8().j(0,x,w)
return x},
aug:function aug(d,e){this.a=d
this.b=e},
dL7(d,e,f,g,h){var x,w,v=e.b
v=$.dg4().a3y(new C.Mb(e.geU().a.a,null,v),new C.G6(v,f,"putData"),g,C.dL5(h),d)
x=$.d83()
w=new C.bgL(v,e)
$.e8().j(0,w,x)
w.aYK(d,e,f,v)
return w},
bgU:function bgU(){},
bgX:function bgX(d,e){this.a=d
this.b=e},
bgV:function bgV(){},
bgW:function bgW(){},
bgY:function bgY(d){this.a=d},
bgL:function bgL(d,e){var _=this
_.b=null
_.c=!1
_.d=null
_.e=$
_.f=d
_.w=e
_.x=$},
dL9(d,e,f){var x=$.a_P(),w=new C.ME(d,f,e,f)
$.e8().j(0,w,x)
return w},
ME:function ME(d,e,f,g){var _=this
_.c=d
_.d=e
_.a=f
_.b=g},
dsR(d,e,f){var x,w,v,u=null
if(d==null)throw A.r(A.mj("channel-error",u,'Unable to establish connection on channel: "'+e+'".',u))
else{x=J.aO(d)
if(x.gF(d)>1){w=x.h(d,0)
w.toString
A.b3(w)
v=A.D(x.h(d,1))
throw A.r(A.mj(w,x.h(d,2),v,u))}else if(x.gc7(d)&&x.h(d,0)==null)throw A.r(A.mj("null-error",u,"Host platform returned null value for non-null return value.",u))}return A.eu(d)},
kP(d,e){var x,w,v,u,t,s
if(d==null?e==null:d===e)return!0
if(typeof d=="number"&&typeof e=="number"){if(isNaN(d)&&isNaN(e))return!0
return!1}x=y.j
if(x.b(d)&&x.b(e))return J.ac(d)===J.ac(e)&&A.TP(d,0,y.z).f5(0,new C.d_A(e))
x=y.f
if(x.b(d)&&x.b(e)){if(d.gF(d)!==e.gF(e))return!1
for(x=d.gdA(),x=x.ga8(x);x.E();){w=x.gY()
u=e.gdA()
u=u.ga8(u)
t=w.a
for(;;){if(!u.E()){v=!1
break}s=u.gY()
if(C.kP(t,s.a))if(C.kP(w.b,s.b)){v=!0
break}else return!1}if(!v)return!1}return!0}return J.p(d,e)},
Di(d){var x,w,v
if(y.j.b(d))return A.bj(J.eF(d,C.e18(),y.X))
if(y.f.b(d)){for(x=d.gdA(),x=x.ga8(x),w=0;x.E();){v=x.gY()
w+=(C.Di(v.a)*31^C.Di(v.b))>>>0}return w}x=typeof d=="number"
if(x&&isNaN(d))return B.j.gJ(9221120237041091e3)
if(x&&d===0)return B.j.gJ(0)
return J.aD(d)},
d_A:function d_A(d){this.a=d},
yC:function yC(d,e){this.a=d
this.b=e},
Mb:function Mb(d,e,f){this.a=d
this.b=e
this.c=f},
G6:function G6(d,e,f){this.a=d
this.b=e
this.c=f},
TV:function TV(d){this.a=d},
a4S:function a4S(d,e){this.a=d
this.b=e},
U_:function U_(d,e,f,g,h,i){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i},
a4Y:function a4Y(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
a4T:function a4T(d,e,f){this.a=d
this.b=e
this.c=f},
cla:function cla(){},
b6b:function b6b(d){this.b=d},
bBE(d,e,f,g,h,i){return new C.aa6(i,h,g,f,d,e,null)},
cHx:function cHx(d,e){this.a=d
this.b=e},
bBG:function bBG(d,e){this.a=d
this.b=e},
aa6:function aa6(d,e,f,g,h,i,j){var _=this
_.c=d
_.e=e
_.w=f
_.x=g
_.y=h
_.z=i
_.a=j},
aiS:function aiS(d,e,f,g,h){var _=this
_.r=_.f=_.e=_.d=$
_.w=null
_.x=d
_.y=$
_.z=null
_.Q=!1
_.at=_.as=null
_.ax=e
_.ch=_.ay=!1
_.CW=f
_.eV$=g
_.bZ$=h
_.c=_.a=null},
cHu:function cHu(d){this.a=d},
cHt:function cHt(d){this.a=d},
cHv:function cHv(d,e){this.a=d
this.b=e},
cHw:function cHw(d,e){this.a=d
this.b=e},
cHr:function cHr(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
cHs:function cHs(d){this.a=d},
cHp:function cHp(d){this.a=d},
cHq:function cHq(d,e){this.a=d
this.b=e},
aMm:function aMm(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t){var _=this
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r
_.cx=s
_.a=t},
Zy:function Zy(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0){var _=this
_.C=d
_.aD=_.am=_.ah=$
_.aw=e
_.aP=_.aY=$
_.b9=!1
_.bP=f
_.bn=0
_.bJ=null
_.ck=g
_.dk=h
_.dJ=i
_.di=j
_.Z=k
_.X=l
_.b6=m
_.bk=n
_.fp=o
_.dh=p
_.bM=q
_.eD=r
_.fq=s
_.h6=t
_.e9=u
_.fJ=!1
_.h_=v
_.JQ$=w
_.dy=x
_.b=_.fy=null
_.c=0
_.y=_.d=null
_.z=!0
_.Q=null
_.as=!1
_.at=null
_.ay=$
_.ch=a0
_.CW=!1
_.cx=$
_.cy=!0
_.db=!1
_.dx=$},
cuD:function cuD(){},
cuC:function cuC(){},
cuE:function cuE(d){this.a=d},
cuF:function cuF(d,e){this.a=d
this.b=e},
xn:function xn(d){this.a=d},
ZM:function ZM(d,e){this.a=d
this.b=e},
aOy:function aOy(d,e){this.d=d
this.a=e},
aKY:function aKY(d,e,f,g){var _=this
_.C=$
_.ah=d
_.JQ$=e
_.dy=f
_.b=_.fy=null
_.c=0
_.y=_.d=null
_.z=!0
_.Q=null
_.as=!1
_.at=null
_.ay=$
_.ch=g
_.CW=!1
_.cx=$
_.cy=!0
_.db=!1
_.dx=$},
cHm:function cHm(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5){var _=this
_.p4=d
_.RG=_.R8=$
_.a=e
_.b=f
_.c=g
_.d=h
_.e=i
_.f=j
_.r=k
_.w=l
_.x=m
_.y=n
_.z=o
_.Q=p
_.as=q
_.at=r
_.ax=s
_.ay=t
_.ch=u
_.CW=v
_.cx=w
_.cy=x
_.db=a0
_.dx=a1
_.dy=a2
_.fr=a3
_.fx=a4
_.fy=a5
_.go=a6
_.id=a7
_.k1=a8
_.k2=a9
_.k3=b0
_.k4=b1
_.ok=b2
_.p1=b3
_.p2=b4
_.p3=b5},
cHn:function cHn(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5){var _=this
_.p4=d
_.R8=$
_.a=e
_.b=f
_.c=g
_.d=h
_.e=i
_.f=j
_.r=k
_.w=l
_.x=m
_.y=n
_.z=o
_.Q=p
_.as=q
_.at=r
_.ax=s
_.ay=t
_.ch=u
_.CW=v
_.cx=w
_.cy=x
_.db=a0
_.dx=a1
_.dy=a2
_.fr=a3
_.fx=a4
_.fy=a5
_.go=a6
_.id=a7
_.k1=a8
_.k2=a9
_.k3=b0
_.k4=b1
_.ok=b2
_.p1=b3
_.p2=b4
_.p3=b5},
cHo:function cHo(d){this.a=d},
aln:function aln(){},
alp:function alp(){},
alx:function alx(){},
bBH:function bBH(){},
bBI:function bBI(){},
aVs:function aVs(){},
btd:function btd(){},
btc:function btc(d){this.a=d},
btb:function btb(){},
b0u:function b0u(){},
c0o:function c0o(){},
bte:function bte(){},
aLh:function aLh(){},
dpf(d){var x
d.M(y.S)
x=A.G(d)
return x.eD},
HY:function HY(d,e){this.a=d
this.b=e},
bBF:function bBF(){},
bta:function bta(){},
awV:function awV(){},
csn:function csn(){},
dNO(){return new C.H8(null)},
H8:function H8(d){this.a=d},
ahh:function ahh(d,e,f,g,h){var _=this
_.w=d
_.x=e
_.y=f
_.z=g
_.Q=!1
_.as=null
_.at=!0
_.ax=-12
_.ay=1
_.ch=null
_.CW=!0
_.cx=0.08
_.cy=0.88
_.db=22
_.dx="classic"
_.dy="a4"
_.fr="noto_sans"
_.fx=h
_.fy=!0
_.k1=_.id=_.go=!1
_.d=$
_.c=_.a=null},
coT:function coT(d){this.a=d},
coU:function coU(d){this.a=d},
coS:function coS(d,e){this.a=d
this.b=e},
coZ:function coZ(d){this.a=d},
coW:function coW(d){this.a=d},
coX:function coX(d){this.a=d},
coY:function coY(d,e){this.a=d
this.b=e},
coV:function coV(d){this.a=d},
cp_:function cp_(d){this.a=d},
cp0:function cp0(d,e){this.a=d
this.b=e},
cp1:function cp1(d){this.a=d},
cp7:function cp7(d,e){this.a=d
this.b=e},
cp3:function cp3(d){this.a=d},
cp4:function cp4(d){this.a=d},
cp5:function cp5(d){this.a=d},
cp6:function cp6(d,e){this.a=d
this.b=e},
cp2:function cp2(d){this.a=d},
cp8:function cp8(d,e){this.a=d
this.b=e},
cp9:function cp9(d){this.a=d},
cpa:function cpa(d,e){this.a=d
this.b=e},
cpb:function cpb(d){this.a=d},
cpe:function cpe(d){this.a=d},
cpf:function cpf(d){this.a=d},
cpd:function cpd(d){this.a=d},
cpI:function cpI(d){this.a=d},
cpJ:function cpJ(d){this.a=d},
cpA:function cpA(d){this.a=d},
cpK:function cpK(d){this.a=d},
cpz:function cpz(d,e){this.a=d
this.b=e},
cph:function cph(d,e){this.a=d
this.b=e},
cpV:function cpV(d,e){this.a=d
this.b=e},
cpy:function cpy(d,e){this.a=d
this.b=e},
cpY:function cpY(d){this.a=d},
cpx:function cpx(d,e){this.a=d
this.b=e},
cpg:function cpg(d,e){this.a=d
this.b=e},
cpZ:function cpZ(d){this.a=d},
cpw:function cpw(d,e){this.a=d
this.b=e},
cq_:function cq_(d,e){this.a=d
this.b=e},
cps:function cps(d){this.a=d},
cpt:function cpt(d,e){this.a=d
this.b=e},
cpu:function cpu(d){this.a=d},
cq0:function cq0(d){this.a=d},
cpr:function cpr(d){this.a=d},
cq1:function cq1(d){this.a=d},
cpq:function cpq(d,e){this.a=d
this.b=e},
cq2:function cq2(d,e){this.a=d
this.b=e},
cpp:function cpp(d,e){this.a=d
this.b=e},
cq3:function cq3(d){this.a=d},
cpo:function cpo(d,e){this.a=d
this.b=e},
cpL:function cpL(d){this.a=d},
cpn:function cpn(d,e){this.a=d
this.b=e},
cpM:function cpM(d,e,f){this.a=d
this.b=e
this.c=f},
cpH:function cpH(d){this.a=d},
cpl:function cpl(d,e){this.a=d
this.b=e},
cpm:function cpm(d){this.a=d},
cpN:function cpN(d){this.a=d},
cpG:function cpG(d){this.a=d},
cpO:function cpO(d){this.a=d},
cpF:function cpF(d,e){this.a=d
this.b=e},
cpP:function cpP(d){this.a=d},
cpE:function cpE(d,e){this.a=d
this.b=e},
cpQ:function cpQ(d){this.a=d},
cpD:function cpD(d,e){this.a=d
this.b=e},
cpR:function cpR(d){this.a=d},
cpC:function cpC(d,e){this.a=d
this.b=e},
cpS:function cpS(d){this.a=d},
cpB:function cpB(d,e){this.a=d
this.b=e},
cpT:function cpT(d){this.a=d},
cpv:function cpv(d,e){this.a=d
this.b=e},
cpU:function cpU(d){this.a=d},
cpk:function cpk(d,e){this.a=d
this.b=e},
cpW:function cpW(d){this.a=d},
cpj:function cpj(d){this.a=d},
cpX:function cpX(d){this.a=d},
cpi:function cpi(d){this.a=d},
cpc:function cpc(d){this.a=d},
due(d,e){if(!y.L.b(d)||!(d instanceof A.pT))A.nT(d,e)
A.nT(new A.nW("firebase_storage",d.b,d.a,null),e)},
dZo(d,e,f){var x=A.os(d,e),w=new A.aM($.aS,f.i("aM<0>"))
w.lA(x)
return w},
hM(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v){return A.Jl(d,e,f,g,h,i,j,"NotoSans",k,l,m,n,A.N([B.py,new A.bK("6d4604afa5f04060d950a66a87213263b042aae55facf737c91367cddaebe0ce",555852),B.mD,new A.bK("ed433ee86e1204a87c81a316e6354d12e6da0366cc5161a5af6cbb1dba42dd2d",557112),B.mE,new A.bK("8510ce55560568b5ef3bcd837ad99fc5dff9183339a20d9e9128ae23ae945e24",556896),B.mF,new A.bK("61ea1e781b9d7b10db9b4a6aa2d855cf2215c316c7cb700aeb067a0440d031e0",556300),B.mG,new A.bK("86553647e178b7a8f5f613ef27d057b69168db555caa4235d1bfee92d01d0273",558152),B.mH,new A.bK("6c302f0c3ac2c7afcfde0f124337360cdceda4f28564fab69d39460e5ecb4392",558384),B.mI,new A.bK("1c657f0687537f6987bb0db652a59dbf90843778c641a0a53ac020372cac10d1",557984),B.nM,new A.bK("942cf876c28c70221162855a2526ead64a9549179ba686215318a5b5216d40a8",558296),B.pF,new A.bK("88894fb78c78bacbfcd1cc7c042abdeb3a9b8039b0cfdef3e745dd4c6b560002",557188),B.vT,new A.bK("ad2425f33f14dd5f7830c02c40ade2d521ea8df3466655fbe55e18ad92e76bb9",571668),B.pz,new A.bK("a30d921dd9f291bbf8a782833570fee090922303f0f730dbe6ca79d0e39da4cf",572400),B.pA,new A.bK("b6b6e33dc999dff2af1ca927ae7ae9a77ddbac8c518a5c9d0b28921debe0533a",572404),B.pB,new A.bK("9f15655bceebde7d143c5985eb8b26d73df858dd35578a65c332fd1a8bd7ebc0",570360),B.pC,new A.bK("23fbd5464cde824423f0661dea66de6ebd5e97d5056ccfb11852761dae75e714",575076),B.pD,new A.bK("4adf048b950f3de6fa34525b5758442b3225169672c0c5642f8510a5a9e280f5",572368),B.pE,new A.bK("ffff9b7a49b243730ebe3341b16d008a72dc3af1c5a761fc9b77a272f229ee5a",572228),B.rK,new A.bK("c937ff3fbf103d2abd2a1180cd8cd77ca8599c6684a57e30149bee8582343558",572316),B.vU,new A.bK("2aa705c8678c53e12eab4b6b1e0aba10b6586b272b55e117f69183aad168b567",571024)],y.D,y.r),o,p,q,r,s,t,u,v)},
hN(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v){return A.Jl(d,e,f,g,h,i,j,"NotoSerif",k,l,m,n,A.N([B.py,new A.bK("b74191583800ec43403f0f36ea56fc9f8410cf71fabd95ed9dafa0d155ead0dd",444480),B.mD,new A.bK("83bde39565b5439caf4a5f3c617f8f3073a7f1d4263d94b9981bff28a3a2e9dc",444976),B.mE,new A.bK("6ecad1000f222bbecd26506dbbca1a075d09dceac3d2766fa5bc2f0470e25786",445012),B.mF,new A.bK("a6e0283968e506c67c3d4ff94093e3ff9f4d7ec3c704ff1cb51382f1e45b66b9",444040),B.mG,new A.bK("573f2e6c8b0eb3d8c159af7700b9968a51fec14d596c7bd81cd62dea6a7f9eb2",445424),B.mH,new A.bK("468d67b7f26a6f8ab83cf43a71de164d1580f62b0c36403e56d5e2963a275d6b",445580),B.mI,new A.bK("1cff8098b873570abf5e194f781e85078d6b250ef5b95eb1e03c390f2ab223e2",445524),B.nM,new A.bK("fb0883890d17c808beb303f586ce302c0d880707fc3ba429cc13111d48670795",446164),B.pF,new A.bK("8f3875c332a4be851f3f6e36410ec41991da972980150a87bfbb24728c1ea0d3",445544),B.vT,new A.bK("6195294f9ca19ef58580818ecf172b3091633d13f44d939ca4cc3772ae8656dc",477936),B.pz,new A.bK("7fe8c904cb3028bc9a106c95f71b3c66d8830cc38d44182499ae55bea5ad74a2",478460),B.pA,new A.bK("79f28a2889179ab380349d59c99406378967fb49b88c9874ca6fa055f4a20856",478108),B.pB,new A.bK("5b92042eafecb92afc515cd3507891dfb3cb7e66aa7feb0f0ac4c94d5106b606",476376),B.pC,new A.bK("5199f10b31e173eaf9289dce837f135565aa196c3c0f0b7421ecf788ae6952f5",477184),B.pD,new A.bK("7cb14d1062b02ca48ba571545c882ab9227b9fd40c5e78fb941dc0cdd2c15f19",477244),B.pE,new A.bK("7c7f44785dfaca5808d42ab219acdd42a19a0a68bae142084b594263bc47b1eb",476572),B.rK,new A.bK("06bb97c589242764bcde8d3714a775440a5772d9cc2e76bf8849d7bda4c9cb47",477852),B.vU,new A.bK("9445924a035b0eca9646e2e766e9ba9a0908573c8350b2a509067b9c011b756d",477688)],y.D,y.r),o,p,q,r,s,t,u,v)},
hS(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v){return A.Jl(d,e,f,g,h,i,j,"RobotoMono",k,l,m,n,A.N([B.py,new A.bK("66fb0366a5fd5462019e22f6ae0a30741dc8f27c0474ff3901dab196212bc956",79984),B.mD,new A.bK("63e70a90afce275e05c817eb2ffffadc2e2daf1073d6cea50181c0f8dc89b6cc",79916),B.mE,new A.bK("0707339daafe005a4f25ffb35c018208ac02f1c35b14405773f36d88a9aad07e",79684),B.mF,new A.bK("c75c21ddc0cad53a5651e0cbb4a0184d71f0b72d05405d2e4121f637479da64e",78924),B.mG,new A.bK("54baeda3df34bf23cfdbdb1a5f162649b8c1ef120944956e9947df76748a384d",78912),B.mH,new A.bK("6693e9456a6412291b6ef0b72b5db1f562392e7f75a7e1665235c48687925d14",79180),B.mI,new A.bK("45c45339ebd8a59b3fc2b1570f504590bb38c546a73d4fc5a98c3f113a0cedb6",79100),B.vT,new A.bK("73bc8efc8111f9ef7909f0d2fbfe8052cd2342f5a84946633ec03e47d887173b",84908),B.pz,new A.bK("4777918f2e0d08fc113e3ee2759623d3bb44feb7434b6432b8fcab21ddad9c85",85280),B.pA,new A.bK("8add2d7b1ee8fca607961238f84c1bd980f5e817cb19d45b70f62b1f6399c25c",85556),B.pB,new A.bK("fe328c08d828298532dac394416685cb4cd6d16dfc3d95e943e13f2683c40aee",85632),B.pC,new A.bK("faadce56c40af2eceb8c364613d8d5d987fe1ec50974af0c4be0a76c0b2a5992",85712),B.pD,new A.bK("2f71241c7ea4c844055ff35acbeba8cab989e938551cbaa2d2adb7cbcc8d8ded",85752),B.pE,new A.bK("3cd6f4b8ba5f447fafc30130d8c3277aa2f6b5ba5a7c23706ddb78394733a7cf",85892)],y.D,y.r),o,p,q,r,s,t,u,v)}},D,E
J=c[1]
A=c[0]
B=c[2]
C=a.updateHolder(c[5],C)
D=c[32]
E=c[27]
C.T7.prototype={
p(d,e){if(e==null)return!1
return e instanceof C.T7&&e.d.a.a===this.d.a.a&&e.e===this.e},
gJ(d){return A.aG(this.d.a.a,this.e,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b)},
l(d){return D.cQ1.l(0)+"(app: "+this.d.a.a+", bucket: "+this.e+")"}}
C.a8d.prototype={
gcq(){return B.h.gaj(this.a.a.a.split("/"))},
bzs(d){var x,w
if(d.e!=null)return d
x=B.h.gaj(this.a.a.a.split("/"))
w=$.dBw().bNr(x,null)
if(w==null)return d
return new A.WA(d.a,d.b,d.c,d.d,w,d.f)},
p(d,e){if(e==null)return!1
return e instanceof C.a8d&&e.a.a.a===this.a.a.a&&e.b.p(0,this.b)},
gJ(d){return A.aG(this.b,this.a.a.a,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b)},
l(d){return D.cQp.l(0)+"(app: "+this.b.d.a.a+", fullPath: "+this.a.a.a+")"}}
C.aAa.prototype={
nd(d,e){return this.bCk(d,e)},
cd(d){return this.nd(d,null)},
bCk(d,e){var x=0,w=A.o(y.h),v,u=this,t
var $async$nd=A.j(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:t=u.a
x=3
return A.d(t.gFl().nd(d,e),$async$nd)
case 3:v=C.bEq(u.b,t.gMc())
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$nd,w)},
d_(d,e,f){return this.a.gFl().d_(new C.bEt(this,d,f),e,f)},
bi(d,e){return this.d_(d,null,e)},
hU(d){var x=0,w=A.o(y.h),v,u=this,t
var $async$hU=A.j(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:t=u.a
x=3
return A.d(t.gFl().hU(d),$async$hU)
case 3:v=C.bEq(u.b,t.gMc())
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$hU,w)},
kr(d,e){return this.a.gFl().bi(new C.bEu(this),y.h).kr(d,e)},
fk(d){return this.kr(d,null)},
$iau:1}
C.aAU.prototype={}
C.zw.prototype={
p(d,e){var x,w
if(e==null)return!1
if(e instanceof C.zw){x=e.b
w=this.b
x=C.a8e(x,e.a.gV()).p(0,C.a8e(w,this.a.gV()))&&x.p(0,w)}else x=!1
return x},
gJ(d){var x=this.b
return A.aG(x,C.a8e(x,this.a.gV()),B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b,B.b)},
l(d){var x=this.a
return D.cQx.l(0)+"(ref: "+C.a8e(this.b,x.gV()).l(0)+", state: "+x.gbf().l(0)+")"}}
C.a5W.prototype={
aFj(d,e){var x,w=d.a.a+"|"+e,v=$.dL4,u=v.h(0,w)
if(u==null){u=$.aS0()
x=new C.a5W(12e4,6e5,6e5,d,e)
$.e8().j(0,x,u)
v.j(0,w,x)
v=x}else v=u
return v},
aiB(d){return C.dmK(this,d)}}
C.aug.prototype={
gbQ8(){var x=this.b
return new C.Mb(x.geU().a.a,null,x.b)},
gbQ9(){var x=this.a.a
return new C.G6(this.b.b,x,B.h.gaj(x.split("/")))},
t1(){var x=0,w=A.o(y.N),v,u=2,t=[],s=this,r,q,p,o,n
var $async$t1=A.j(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:u=4
x=7
return A.d($.dg4().a3x(s.gbQ8(),s.gbQ9()),$async$t1)
case 7:r=e
v=r
x=1
break
u=2
x=6
break
case 4:u=3
n=t.pop()
q=A.aa(n)
p=A.ba(n)
C.due(q,p)
x=6
break
case 3:x=2
break
case 6:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$t1,w)},
aic(d,e){var x=$.dmG
$.dmG=x+1
return C.dL7(x,this.b,this.a.a,d,e)}}
C.bgU.prototype={
aYK(d,e,f,g){var x=this,w=new C.bgX(x,f).$0()
x.e=A.dqR(w,new C.bgV(),new C.bgW(),A.C(w).i("aY.T"))
x.x=C.dL9(x.w,B.Ec,A.N(["path",f,"bytesTransferred",0,"totalBytes",1],y.N,y.z))},
gMc(){var x=this.x
x===$&&A.b()
return x},
gFl(){var x=0,w=A.o(y.i),v,u=this,t
var $async$gFl=A.j(function(d,e){if(d===1)return A.l(e,w)
for(;;)switch(x){case 0:t=u.c
if(t&&u.b==null){t=u.x
t===$&&A.b()
v=A.dR(t,y.i)
x=1
break}else if(t&&u.b!=null){t=u.b
t.toString
v=C.dZo(t,A.p7(),y.i)
x=1
break}else{t=u.e
t===$&&A.b()
t.gaj(0).cd(new C.bgY(u))
t=u.d
v=(t==null?u.d=new A.bA(new A.aM($.aS,y.x),y.M):t).a
x=1
break}case 1:return A.m(v,w)}})
return A.n($async$gFl,w)}}
C.bgL.prototype={}
C.ME.prototype={
gV(){return C.dmK(this.c,this.d.h(0,"path"))}}
C.yC.prototype={
U(){return"InternalStorageTaskState."+this.b}}
C.Mb.prototype={
p(d,e){var x=this
if(e==null)return!1
if(!(e instanceof C.Mb)||A.a6(e)!==A.a6(x))return!1
if(x===e)return!0
return C.kP(x.a,e.a)&&C.kP(x.b,e.b)&&C.kP(x.c,e.c)},
gJ(d){var x=this,w=[A.a6(x)]
B.h.B(w,[x.a,x.b,x.c])
return C.Di(w)}}
C.G6.prototype={
p(d,e){var x=this
if(e==null)return!1
if(!(e instanceof C.G6)||A.a6(e)!==A.a6(x))return!1
if(x===e)return!0
return C.kP(x.a,e.a)&&C.kP(x.b,e.b)&&C.kP(x.c,e.c)},
gJ(d){var x=this,w=[A.a6(x)]
B.h.B(w,[x.a,x.b,x.c])
return C.Di(w)},
gcq(){return this.c}}
C.TV.prototype={
p(d,e){if(e==null)return!1
if(!(e instanceof C.TV)||A.a6(e)!==A.a6(this))return!1
if(this===e)return!0
return C.kP(this.a,e.a)},
gJ(d){var x=[A.a6(this)]
B.h.B(x,[this.a])
return C.Di(x)}}
C.a4S.prototype={
p(d,e){var x=this
if(e==null)return!1
if(!(e instanceof C.a4S)||A.a6(e)!==A.a6(x))return!1
if(x===e)return!0
return C.kP(x.a,e.a)&&C.kP(x.b,e.b)},
gJ(d){var x=[A.a6(this)]
B.h.B(x,[this.a,this.b])
return C.Di(x)}}
C.U_.prototype={
Oj(){var x=this
return[x.a,x.b,x.c,x.d,x.e,x.f]},
p(d,e){var x=this
if(e==null)return!1
if(!(e instanceof C.U_)||A.a6(e)!==A.a6(x))return!1
if(x===e)return!0
return C.kP(x.a,e.a)&&C.kP(x.b,e.b)&&C.kP(x.c,e.c)&&C.kP(x.d,e.d)&&C.kP(x.e,e.e)&&C.kP(x.f,e.f)},
gJ(d){var x=[A.a6(this)]
B.h.B(x,this.Oj())
return C.Di(x)}}
C.a4Y.prototype={
Oj(){var x=this
return[x.a,x.b,x.c,x.d]},
p(d,e){var x=this
if(e==null)return!1
if(!(e instanceof C.a4Y)||A.a6(e)!==A.a6(x))return!1
if(x===e)return!0
return C.kP(x.a,e.a)&&C.kP(x.b,e.b)&&C.kP(x.c,e.c)&&C.kP(x.d,e.d)},
gJ(d){var x=[A.a6(this)]
B.h.B(x,this.Oj())
return C.Di(x)}}
C.a4T.prototype={
p(d,e){var x=this
if(e==null)return!1
if(!(e instanceof C.a4T)||A.a6(e)!==A.a6(x))return!1
if(x===e)return!0
return C.kP(x.a,e.a)&&C.kP(x.b,e.b)&&C.kP(x.c,e.c)},
gJ(d){var x=this,w=[A.a6(x)]
B.h.B(w,[x.a,x.b,x.c])
return C.Di(w)}}
C.cla.prototype={
cc(d,e){var x=this
if(A.fv(e)){d.ca(4)
d.yz(e)}else if(e instanceof C.yC){d.ca(129)
x.cc(d,e.a)}else if(e instanceof C.Mb){d.ca(130)
x.cc(d,[e.a,e.b,e.c])}else if(e instanceof C.G6){d.ca(131)
x.cc(d,[e.a,e.b,e.c])}else if(e instanceof C.TV){d.ca(132)
x.cc(d,[e.a])}else if(e instanceof C.a4S){d.ca(133)
x.cc(d,[e.a,e.b])}else if(e instanceof C.U_){d.ca(134)
x.cc(d,e.Oj())}else if(e instanceof C.a4Y){d.ca(135)
x.cc(d,e.Oj())}else if(e instanceof C.a4T){d.ca(136)
x.cc(d,[e.a,e.b,e.c])}else x.Cv(d,e)},
lU(d,e){var x,w,v,u,t,s,r,q,p=this
switch(d){case 129:x=A.cc(p.cZ(e))
return x==null?null:D.bJZ[x]
case 130:w=p.cZ(e)
w.toString
y.W.a(w)
v=J.aO(w)
u=v.h(w,0)
u.toString
A.b3(u)
t=A.D(v.h(w,1))
w=v.h(w,2)
w.toString
return new C.Mb(u,t,A.b3(w))
case 131:w=p.cZ(e)
w.toString
y.W.a(w)
v=J.aO(w)
u=v.h(w,0)
u.toString
A.b3(u)
t=v.h(w,1)
t.toString
A.b3(t)
w=v.h(w,2)
w.toString
return new C.G6(u,t,A.b3(w))
case 132:w=p.cZ(e)
w.toString
w=y.n.a(J.k(y.W.a(w),0))
return new C.TV(w==null?null:w.fN(0,y.T,y.X))
case 133:w=p.cZ(e)
w.toString
y.W.a(w)
v=J.aO(w)
u=v.h(w,0)
u.toString
return new C.a4S(A.cn(u),A.D(v.h(w,1)))
case 134:w=p.cZ(e)
w.toString
y.W.a(w)
v=J.aO(w)
u=A.D(v.h(w,0))
t=A.D(v.h(w,1))
s=A.D(v.h(w,2))
r=A.D(v.h(w,3))
q=A.D(v.h(w,4))
w=y.n.a(v.h(w,5))
if(w==null)w=null
else{v=y.T
v=w.fN(0,v,v)
w=v}return new C.U_(u,t,s,r,q,w)
case 135:w=p.cZ(e)
w.toString
y.W.a(w)
v=J.aO(w)
u=v.h(w,0)
u.toString
A.cn(u)
t=y.d0.a(v.h(w,1))
s=v.h(w,2)
s.toString
y.Y.a(s)
w=v.h(w,3)
w.toString
return new C.a4Y(u,t,s,A.cn(w))
case 136:w=p.cZ(e)
w.toString
v=y.W
v.a(w)
u=J.aO(w)
t=u.h(w,0)
t.toString
s=y.cX
t=J.is(v.a(t),s)
r=A.D(u.h(w,1))
w=u.h(w,2)
w.toString
return new C.a4T(t,r,J.is(v.a(w),s))
default:return p.GL(d,e)}}}
C.b6b.prototype={
a3x(d,e){return this.bRc(d,e)},
bRc(d,e){var x=0,w=A.o(y.N),v,u=this,t,s,r,q
var $async$a3x=A.j(function(f,g){if(f===1)return A.l(g,w)
for(;;)switch(x){case 0:t="dev.flutter.pigeon.firebase_storage_platform_interface.FirebaseStorageHostApi.referenceGetDownloadURL"+u.b
r=C
q=y.A
x=3
return A.d(new A.i3(t,D.Rm,null,y.J).eZ([d,e]),$async$a3x)
case 3:s=r.dsR(q.a(g),t,!1)
s.toString
v=A.b3(s)
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$a3x,w)},
a3y(d,e,f,g,h){return this.bRd(d,e,f,g,h)},
bRd(d,e,f,g,h){var x=0,w=A.o(y.N),v,u=this,t,s,r,q
var $async$a3y=A.j(function(i,j){if(i===1)return A.l(j,w)
for(;;)switch(x){case 0:t="dev.flutter.pigeon.firebase_storage_platform_interface.FirebaseStorageHostApi.referencePutData"+u.b
r=C
q=y.A
x=3
return A.d(new A.i3(t,D.Rm,null,y.J).eZ([d,e,f,g,h]),$async$a3y)
case 3:s=r.dsR(q.a(j),t,!1)
s.toString
v=A.b3(s)
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$a3y,w)}}
C.cHx.prototype={
U(){return"_SliderType."+this.b}}
C.bBG.prototype={
U(){return"SliderInteraction."+this.b}}
C.aa6.prototype={
a6(){var x=new A.av1("Slider ValueIndicator")
x.UP()
return new C.aiS(new A.c5(null,y.B),x,new A.U9(),null,null)}}
C.aiS.prototype={
gdP(){this.a.toString
var x=this.at
x.toString
return x},
au(){var x,w=this,v=null
w.aE()
w.d=A.cO(v,B.eX,v,1,v,w)
w.e=A.cO(v,B.eX,v,1,v,w)
w.f=A.cO(v,B.pj,v,1,v,w)
w.r=A.cO(v,B.bg,v,1,v,w)
x=w.f
w.a.toString
x.sA(1)
w.r.sA(w.aqm(w.a.c))
w.y=A.N([D.cQN,new A.h0(w.gaZF(),new A.dD(A.a([],y.k),y.m),y.d)],y.u,y.E)
w.a.toString
if(w.at==null)w.at=A.kX(!0,v,!0,!0,v,v,!1)},
t(){var x=this,w=x.w
if(w!=null)w.aO()
w=x.d
w===$&&A.b()
w.t()
w=x.e
w===$&&A.b()
w.t()
w=x.f
w===$&&A.b()
w.t()
w=x.r
w===$&&A.b()
w.t()
w=x.at
if(w!=null)w.t()
x.aXJ()},
bcp(d){var x,w=this,v=w.biQ(d)
if(w.as!==v){w.as=v
x=w.a
if(v!==x.c)x.e.$1(v)}},
acd(d){this.u(new C.cHu(this))
this.a.toString},
acb(d){var x=this
x.u(new C.cHt(x))
x.as=null
x.a.toString},
aZG(d){var x,w=this.x,v=$.aP.bc$.x.h(0,w).M(y.I).w
switch(d.a.a){case 2:x=!0
break
case 3:x=!1
break
case 1:x=v===B.dP
break
case 0:x=v===B.bV
break
default:x=null}w=$.aP.bc$.x.h(0,w).gaU()
w.toString
y.Q.a(w)
return x?w.aHD():w.aFf()},
bdg(d){if(d!==this.ay)this.u(new C.cHv(this,d))},
bdL(d){if(d!==this.ch)this.u(new C.cHw(this,d))},
biQ(d){var x=this.a,w=x.x
x=x.w
return d*(w-x)+x},
aqm(d){var x=this.a,w=x.x,v=x.w,u=w>v?(d-v)/(w-v):0,t=x.y
x=B.l.aL(u*t)
return x/t},
P(d){this.a.toString
switch(0){case 0:return this.b1d(d)}},
b1d(b9){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4=this,b5=null,b6={},b7=A.G(b9),b8=b6.a=C.dpf(b9)
b4.a.toString
switch(!0){case!0:x=new C.cHn(b9,4,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5)
break
case!1:x=new C.cHm(b9,4,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5,b5)
break
default:x=b5}w=A.bd(y.C)
if(b4.ch)w.H(0,B.aZ)
if(b4.ay)w.H(0,B.b_)
if(b4.Q)w.H(0,B.oz)
v=b8.dx
if(v==null)v=x.gG1()
if(v instanceof C.awV){u=b8.ay
if(u==null){t=b7.ax
s=t.k3
t=t.k2
u=A.Ks(A.bl(153,s.O()>>>16&255,s.O()>>>8&255,s.O()&255),A.bl(B.l.aL(229.5),t.O()>>>16&255,t.O()>>>8&255,t.O()&255))}}else{b4.a.toString
u=b8.ay
if(u==null)u=x.gG0()}r=b8.id
if(r==null)r=x.gG2()
t=A.cZ(b9,B.yh)
t=t==null?b5:t.ay
if(t===!0)r=r.c5(B.bJ)
t=b6.a
s=t.a
if(s==null)s=x.a
b4.a.toString
q=t.b
if(q==null)q=x.gxo()
b4.a.toString
p=b6.a.c
if(p==null)p=x.gy9()
b4.a.toString
o=b6.a.d
if(o==null)o=x.gC5()
n=b6.a.e
if(n==null)n=x.gEu()
m=b6.a.r
if(m==null)m=x.gEw()
l=b6.a.f
if(l==null)l=x.gEx()
b4.a.toString
k=b6.a.w
if(k==null)k=x.gDR()
b4.a.toString
j=b6.a.x
if(j==null)j=x.gF7()
i=b6.a.y
if(i==null)i=x.gEt()
h=b6.a.z
if(h==null)h=x.gEv()
b4.a.toString
g=b6.a.Q
if(g==null)g=x.gmw()
f=b6.a.at
if(f==null)f=x.gEy()
e=new C.cHr(b6,b4,w,x).$0()
d=b6.a.db
if(d==null)d=x.gFU()
a0=b6.a.cx
if(a0==null)a0=x.gFQ()
a1=b6.a.cy
if(a1==null)a1=x.gFP()
a2=b6.a.CW
if(a2==null)a2=x.gFp()
b4.a.toString
a3=b6.a
a4=a3.go
if(a4==null)a4=D.Nn
a5=a3.p1
if(a5==null)a5=x.p1
a6=b6.a.p2
x=a6==null?x.p2:a6
b6.a=t.aeH(k,q,i,n,h,m,l,f,j,p,e,a2,a3.ok,o,a4,g,a1,a5,a0,x,s,d,u,v,r)
b4.a.toString
d=A.dK(b5,w,y.at)
if(d==null)a7=b5
else a7=d
if(a7==null)a7=A.bI4(w)
b4.a.toString
a8=b5
switch(b7.w.a){case 0:case 1:case 2:case 3:case 4:break
case 5:a8=new C.cHp(b4)
break}switch(A.aN(b9,B.uI,y.w).w.CW.a){case 1:x=D.bYy
break
case 0:x=D.bYR
break
default:x=b5}w=b6.a.id
a9=w==null?b5:w.r
if(a9==null)a9=14
b0=a9===0?14:a9
w=A.cZ(b9,B.cA)
w=w==null?b5:w.gde()
b1=(w==null?B.c3:w).lJ(0,1.3)
w=b1.bV(b0)
t=b4.aqm(b4.a.c)
s=b4.a
q=s.y
s=s.z
p=b6.a
o=new C.cHs(b9).$0()
n=b4.a
m=n.x
n=n.w
n=m>n?b4.gbco():b5
b2=new A.Ku(b4.CW,new C.aMm(t,b5,q,s,p,w/b0,o,n,b4.gacc(),b4.gaca(),b5,a8,b4,b4.ay,b4.ch,D.cfi,b4.x),b5)
b3=b6.a.ok
if(b3!=null)b2=new A.T(b3,b2,b5)
w=b4.y
w===$&&A.b()
return A.arA(w,!1,new A.UR(b4.ax,new C.cHq(b6,b4),b2,B.aaS,b5),!0,b4.gdP(),!1,a7,b5,b4.gbdf(),b4.gbdK(),x)},
b2v(d){var x,w=this,v=A.d9w(new C.aOy(w,null),w.CW,B.W,!0)
A:{if(D.agt===d){x=B.b0
break A}if(D.Nn===d){w.a.toString
x=v
break A}if(D.agq===d){w.a.toString
x=B.b0
break A}if(D.DY===d||D.agr===d||D.ags===d){x=v
break A}x=null}return x}}
C.aMm.prototype={
bN(d){var x,w=this,v=null,u=w.ay,t=d.M(y.I).w,s=A.G(d),r=A.aN(d,B.uJ,y.w).w.cx
t=new C.Zy(u,A.Ct(v,v,v,v,v,B.Q,v,v,B.kv,B.cP),w.ax,w.d,w.e,s.w,w.at,w.f,w.r,w.w,w.x,w.y,w.z,w.Q,w.as,t,w.ch,w.CW,w.cx,!1,new A.cp(),A.bs(y.g))
t.bL()
t.IG()
x=new A.arU(A.I(y.bL,y.y))
s=A.b9v(v,v)
s.w=x
s.ch=t.gacc()
s.CW=t.gbvf()
s.cx=t.gaca()
s.cy=t.gb8D()
s.b=r
t.aY=s
s=A.X8(v,-1,v)
s.w=x
s.C=t.gbgu()
s.ah=t.gbgB()
s.b=r
t.aP=s
s=u.d
s===$&&A.b()
t.ah=A.cX(B.bQ,s,v)
s=u.e
s===$&&A.b()
t.am=A.cX(B.bQ,s,v)
u=u.f
u===$&&A.b()
t.aD=A.cX(B.kA,u,v)
return t},
bW(d,e){var x,w,v=this
e.sbHv(v.f)
e.sA(v.d)
e.saPe(v.e)
e.svL(v.r)
e.saRp(v.w)
e.sqA(v.x)
e.saP6(v.y)
e.slt(v.z)
e.bM=v.Q
e.eD=v.as
e.sds(d.M(y.I).w)
e.saPl(v.at)
e.bP=v.ax
e.sbQc(A.G(d).w)
e.sdl(v.ch)
e.sbLv(v.CW)
x=A.aN(d,B.uJ,y.w).w.cx
w=e.aY
w===$&&A.b()
w.b=x
w=e.aP
w===$&&A.b()
w.b=x
e.sbAE(v.cx)}}
C.Zy.prototype={
gaav(){var x=this.gazI()
return new A.X(x,new C.cuD(),A.ab(x).i("X<1,al>")).ib(0,B.l7)},
gaau(){var x=this.gazI()
return new A.X(x,new C.cuC(),A.ab(x).i("X<1,al>")).ib(0,B.l7)},
gazI(){var x,w,v,u=this,t=u.b6
t.CW.toString
if(t.ok!=null){x=u.dh
w=u.Z
t=t.cy.U9(x!=null,w>0).b}else t=48
x=u.b6
w=u.dh
v=u.Z
x=x.cy.U9(w!=null,v>0)
w=u.b6
return A.a([new A.am(48,t),x,w.cx.a55(u.dh!=null,w)],y.e)},
gZX(){var x=this.b6
return x.db.aOw(!1,this,x)},
sA(d){var x,w,v=this,u=v.Z,t=u>0?v.Nk(d):d
if(t===v.ck)return
v.ck=t
u=v.Z
x=v.C.r
if(u>0){x===$&&A.b()
u=x.x
u===$&&A.b()
w=Math.abs(t-u)
x.e=w!==0?new A.bM(B.l.aL(75e3*(1/w))):B.bg
x.z=B.f6
x.o1(t,B.kA,null)}else{x===$&&A.b()
x.sA(t)}v.cY()},
saPe(d){var x=this
if(d==x.dk)return
x.dk=d
x.bR()
x.cY()},
sbQc(d){if(this.dJ===d)return
this.dJ=d
this.cY()},
saPl(d){return},
sbHv(d){if(d===this.Z)return
this.Z=d
this.bR()},
svL(d){if(d===this.X)return
this.X=d
this.IG()},
saRp(d){if(d.p(0,this.b6))return
this.b6=d
this.IG()},
sqA(d){if(d===this.bk)return
this.bk=d
this.IG()},
saP6(d){if(d.p(0,this.fp))return
this.fp=d
this.bR()},
slt(d){var x,w,v=this
if(J.p(d,v.dh))return
x=v.dh
v.dh=d
w=d!=null
if(x!=null!==w){x=v.C.f
if(w){x===$&&A.b()
x.cI()}else{x===$&&A.b()
x.dZ()}v.bR()
v.cY()}},
sds(d){if(d===this.fq)return
this.fq=d
this.IG()},
sdl(d){var x,w,v=this
if(d===v.h6)return
v.h6=d
x=v.C
w=x.d
if(d){w===$&&A.b()
w.cI()
if(v.gM8()){x=x.e
x===$&&A.b()
x.cI()}}else{w===$&&A.b()
w.dZ()
if(v.gM8()){x=x.e
x===$&&A.b()
x.dZ()}}v.cY()},
sbLv(d){if(d===this.e9)return
this.e9=d
this.aBk(d)},
sbLw(d){var x=this
if(d===x.fJ)return
x.fJ=d
x.aBk(x.e9)},
sbAE(d){if(d===this.h_)return
this.h_=d
this.cY()},
aBk(d){var x,w=this
if(d&&w.fJ){x=w.C.d
x===$&&A.b()
x.cI()}else if(!w.b9&&!w.h6){x=w.C.d
x===$&&A.b()
x.dZ()}},
gM8(){var x=this.b6.go
x.toString
A:{if(D.Nn===x){x=this.Z>0
break A}if(D.agq===x){x=this.Z
x=x<=0
break A}if(D.agr===x||D.ags===x){x=!0
break A}if(D.agt===x||D.DY===x){x=!1
break A}x=null}return x},
IG(){var x=this,w=null,v=x.aw
v.sai(A.fP(w,w,w,w,w,w,w,w,w,x.b6.id,x.X))
v.sds(x.fq)
v.sde(new A.m1(x.bk))
v.vM()
x.aJ()},
Mv(){this.a68()
this.aw.aJ()
this.IG()},
by(d){var x,w,v=this
v.aXt(d)
x=v.ah
x===$&&A.b()
w=v.ghR()
x.a.aG(w)
x=v.am
x===$&&A.b()
x.a.aG(w)
x=v.aD
x===$&&A.b()
x.a.aG(w)
x=v.C.r
x===$&&A.b()
x.dq()
x.eQ$.H(0,w)},
bl(){var x,w=this,v=w.ah
v===$&&A.b()
x=w.ghR()
v.a.a7(x)
v=w.am
v===$&&A.b()
v.a.a7(x)
v=w.aD
v===$&&A.b()
v.a.a7(x)
v=w.C.r
v===$&&A.b()
v.a7(x)
w.aXu()},
t(){var x=this,w=x.aY
w===$&&A.b()
w.p2.al(0)
w.td()
w=x.aP
w===$&&A.b()
w.xg()
w.td()
x.aw.t()
w=x.aD
w===$&&A.b()
w.t()
w=x.am
w===$&&A.b()
w.t()
w=x.ah
w===$&&A.b()
w.t()
x.jK()},
bbG(d){var x
switch(this.fq.a){case 0:x=1-d
break
case 1:x=d
break
default:x=null}return x},
Nk(d){var x=A.ao(d,0,1),w=this.Z
return w>0?B.l.aL(x*w)/w:x},
azP(d){var x,w,v,u=this,t=u.C
if(t.c==null)return
if(!u.b9&&u.dh!=null){switch(u.h_.a){case 0:case 1:u.b9=!0
x=u.i7(d)
w=u.gZX()
v=u.gZX()
u.bn=u.bbG((x.a-w.a)/(v.c-v.a))
break
case 3:x=u.bJ
x.toString
if(x.k(0,u.i7(d))){u.b9=!0
u.bn=u.ck}break
case 2:u.b9=!0
u.bn=u.ck
break}if(u.b9){u.bM.$1(u.Nk(u.ck))
x=u.dh
x.toString
x.$1(u.Nk(u.bn))
x=t.d
x===$&&A.b()
x.cI()
if(u.gM8()){x=t.e
x===$&&A.b()
x.cI()
x=t.w
if(x!=null)x.aO()
t.w=A.eq(new A.bM(5e5),new C.cuE(u))}}}},
a8s(){var x,w,v=this,u=v.C
if(u.c==null)return
x=v.b9
if(x){v.eD.$1(v.Nk(v.bn))
x=v.b9=!1
v.bn=0
w=u.d
w===$&&A.b()
w.dZ()
if(v.gM8()?u.w==null:x){u=u.e
u===$&&A.b()
u.dZ()}}},
acd(d){this.azP(d.a)},
bvg(d){var x,w,v,u=this
if(u.C.c==null)return
switch(u.h_.a){case 0:case 2:case 3:if(u.b9&&u.dh!=null){x=d.e
x.toString
w=u.gZX()
v=x/(w.c-w.a)
w=u.bn
switch(u.fq.a){case 0:x=-v
break
case 1:x=v
break
default:x=null}x=w+x
u.bn=x
w=u.dh
w.toString
w.$1(u.Nk(x))}break
case 1:break}},
acb(d){this.a8s()},
bgv(d){this.azP(d.a)},
bgC(d){this.a8s()},
lN(d){return!0},
ql(d,e){var x,w=this
if(w.C.c==null)return
if(y.Z.b(d)&&w.dh!=null){x=w.aY
x===$&&A.b()
x.rd(d)
x=w.aP
x===$&&A.b()
x.rd(d)}if(w.dh!=null&&w.bJ!=null){x=w.bJ
x.toString
w.sbLw(x.k(0,d.geA()))}},
cD(d){return 144+this.gaav()},
cB(d){return 144+this.gaav()},
cC(d){var x=this.b6.a
x.toString
return Math.max(x,this.gaau())},
cA(d){var x=this.b6.a
x.toString
return Math.max(x,this.gaau())},
gnY(){return!0},
e6(d){var x,w=d.b
w=w<1/0?w:144+this.gaav()
x=d.d
if(!(x<1/0)){x=this.b6.a
x.toString
x=Math.max(x,this.gaau())}return new A.am(w,x)},
bq(a9,b0){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5=this,a6=null,a7=a5.C,a8=a7.r
a8===$&&A.b()
a8=a8.x
a8===$&&A.b()
x=a5.fq
A:{w=B.dP===x
if(w&&a5.dk==null){a8=new A.be(1-a8,a6)
break A}if(w){v=a5.dk
v.toString
v=new A.be(1-a8,1-v)
a8=v
break A}if(B.bV===x){a8=new A.be(a8,a5.dk)
break A}a8=a6}u=a8.a
t=a6
s=a8.b
t=s
r=u
a8=a5.b6
v=a5.Z
q=a8.db.aOx(v>0,b0,a5,a8)
p=a5.ap5(q,r)
if(a5.dh!=null){a5.b6.CW.toString
a5.bJ=A.uW(p,24)}if(t!=null){a8=q.a
o=new A.V(a8+t*(q.c-a8),q.gcw().b)}else o=a6
a8=a5.b6.p1
if(a8==null)n=a6
else{a8=a8.az(A.bd(y.C))
n=a8==null?a6:a8.a}a8=a5.b6.p1
if(a8==null)m=a6
else{a8=a8.az(A.bd(y.C))
m=a8==null?a6:a8.b}a8=a5.b6
l=a8.p2
a8=a8.p1
if(a8==null)k=a6
else{a8=a8.az(A.ew([B.b7],y.C))
k=a8==null?a6:a8.a}if(a5.b9&&n!=null&&k!=null&&l!=null){j=n>0?k:n
if(l>0)l-=(n-k)/2
n=j}a8=a5.b6
v=a8.db
v.toString
a8=a8.bED(l)
i=a5.aD
i===$&&A.b()
h=a5.fq
g=a5.Z
v.bPH(a9,b0,i,g>0,a5.dh!=null,a5,o,a8,h,p)
a8=a5.ah
a8===$&&A.b()
if(a8.gbU()!==B.bU){v=a5.b6
v.CW.toString
if(a5.fp.gab(0))a5.gW()
f=a9.gdY()
a8=new A.bF(0,24,y.t).aI(a8.gA())
$.b_()
i=A.bQ()
i.r=v.ax.gA()
f.ju(p,a8,i)}a8=a5.Z
if(a8>0){v=a5.b6
e=q.d-q.b
i=q.a
d=q.c-i-e
if(d/a8>=3*v.cx.a55(a5.dh!=null,v).a){a0=q.gcw().b
for(a8=e/2,a1=0;v=a5.Z,a1<=v;++a1){h=a5.b6
g=a5.aD
a2=a5.fq
h.cx.bPI(a9,new A.V(i+a1/v*d+a8,a0),g,a5.dh!=null,a5,h,a2,p)}a8=v}}v=!1
if(a5.dh!=null){if(a5.gM8()){v=a5.am
v===$&&A.b()
v=v.gbU()!==B.bU}else v=!1
v=v||a5.b6.go===D.DY}if(v)a7.z=new C.cuF(a5,p)
else a7.z=null
a7=a5.b6
v=a7.cy
v.toString
i=a5.ah
h=a5.aD
if(n!=null&&m!=null)a7=a7.bEB(new A.cx(new A.am(n,m),y.s))
g=a5.fq
a2=a5.ck
a3=a5.bk
a4=a5.fp
if(a4.gab(0))a4=a5.gW()
v.a3_(a9,p,i,h,a8>0,a5.aw,a5,a4,a7,g,a3,a2)},
ap5(d,e){var x,w,v,u,t,s,r,q,p=this
p.b6.db.gbMC()
x=d.d-d.b
w=p.Z>0
v=d.a
u=d.c
t=u-v
s=w?v+e*(t-x)+x/2:v+e*t
t=p.b6
r=p.dh
q=x>t.cy.U9(r!=null,w).a/2?x/2:0
return new A.V(A.ao(s,v+q,u-q),d.gcw().b)},
gbsO(){var x,w=this
switch(w.fq.a){case 0:x=1-w.ck
break
case 1:x=w.ck
break
default:x=null}return w.ap5(w.gZX(),x)},
xq(d,e,f){d.sdm(A.VT(this.gbsO(),48,48))
d.ajf(e)},
hO(d){var x,w=this
w.ld(d)
d.a=!0
d.sah1(w.dh!=null)
d.bw=new A.i2(w.X,B.ef)
d.r=!0
d.saIo(!0)
d.sa2d(w.dh!=null)
d.sqp(w.h6)
x=w.bP
if(x!=null)d.sSD(x)
d.aP=w.fq
d.r=!0
if(w.dh!=null){d.sSF(w.gbLI())
d.sSC(w.gbGB())
d.sSE(w.gbOF())}x=w.ck
d.C=new A.i2(""+B.l.aL(x*100)+"%",B.ef)
d.r=!0
d.ah=new A.i2(""+B.l.aL(A.ao(x+w.gZ6(),0,1)*100)+"%",B.ef)
d.am=new A.i2(""+B.l.aL(A.ao(x-w.gZ6(),0,1)*100)+"%",B.ef)},
gZ6(){var x=this.Z
return 1/x},
bOG(){if(this.dh!=null){var x=this.C
if(x.c==null)return
if(!this.h6)x.gdP().ic()}},
aHD(){var x,w=this
if(w.dh!=null){w.bM.$1(A.ao(w.ck,0,1))
x=A.ao(w.ck+w.gZ6(),0,1)
w.dh.$1(x)
w.eD.$1(x)
if(w.C.c==null)return}},
aFf(){var x,w=this
if(w.dh!=null){w.bM.$1(A.ao(w.ck,0,1))
x=A.ao(w.ck-w.gZ6(),0,1)
w.dh.$1(x)
w.eD.$1(x)
if(w.C.c==null)return}}}
C.xn.prototype={}
C.ZM.prototype={
U(){return"_SliderAdjustmentType."+this.b}}
C.aOy.prototype={
bN(d){var x,w=new C.aKY(this.d,!1,new A.cp(),A.bs(y.g))
w.bL()
x=w.ah.e
x===$&&A.b()
w.C=A.cX(B.bQ,x,null)
return w},
bW(d,e){e.ah=this.d}}
C.aKY.prototype={
gnY(){return!0},
by(d){var x,w,v=this
v.aXx(d)
x=v.C
x===$&&A.b()
w=v.ghR()
x.a.aG(w)
x=v.ah.r
x===$&&A.b()
x.dq()
x.eQ$.H(0,w)},
bl(){var x,w=this,v=w.C
v===$&&A.b()
x=w.ghR()
v.a.a7(x)
v=w.ah.r
v===$&&A.b()
v.a7(x)
w.aXy()},
bq(d,e){var x=this.ah.z
if(x!=null)x.$2(d,e)},
e6(d){return new A.am(A.ao(0,d.a,d.b),A.ao(0,d.c,d.d))},
t(){var x=this.C
x===$&&A.b()
x.t()
this.jK()}}
C.cHm.prototype={
gh3(){var x,w=this,v=w.R8
if(v===$){x=A.G(w.p4)
w.R8!==$&&A.bx()
v=w.R8=x.ax}return v},
gxo(){return this.gh3().b},
gy9(){return this.gh3().b.bG(0.24)},
gC5(){return this.gh3().b.bG(0.54)},
gEu(){var x=this.gh3().k3
return A.bl(82,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gEw(){var x=this.gh3().k3
return A.bl(31,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gEx(){var x=this.gh3().k3
return A.bl(31,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gDR(){return this.gh3().c.bG(0.54)},
gF7(){return this.gh3().b.bG(0.54)},
gEt(){return this.gh3().c.bG(0.12)},
gEv(){var x=this.gh3().k3
return A.bl(31,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gmw(){return this.gh3().b},
gEy(){var x=this.gh3(),w=x.k3
return A.Ks(A.bl(97,w.O()>>>16&255,w.O()>>>8&255,w.O()&255),x.k2)},
gdC(){return this.gh3().b.bG(0.12)},
gG2(){var x=A.G(this.p4).ok.y
x.toString
return x.bb(this.gh3().c)},
gG0(){var x,w,v,u=this,t=u.RG
if(t===$){x=C.dpf(u.p4)
u.RG!==$&&A.bx()
u.RG=x
t=x}if(t.dx instanceof C.bte){w=u.gh3()
v=w.xr
return v==null?w.k3:v}return u.gh3().b},
gG1(){return D.arc},
gFP(){return D.R9},
gFU(){return D.Ra},
gFp(){return D.R8},
gFQ(){return D.afx}}
C.cHn.prototype={
gh3(){var x,w=this,v=w.R8
if(v===$){x=A.G(w.p4)
w.R8!==$&&A.bx()
v=w.R8=x.ax}return v},
gxo(){return this.gh3().b},
gy9(){var x=this.gh3(),w=x.RG
return w==null?x.k2:w},
gC5(){return this.gh3().b.bG(0.54)},
gEu(){var x=this.gh3().k3
return A.bl(97,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gEw(){var x=this.gh3().k3
return A.bl(31,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gEx(){var x=this.gh3().k3
return A.bl(31,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gDR(){return this.gh3().c.bG(0.38)},
gF7(){var x=this.gh3(),w=x.rx
x=w==null?x.k3:w
return A.bl(97,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gEt(){var x=this.gh3().k3
return A.bl(97,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gEv(){var x=this.gh3().k3
return A.bl(97,x.O()>>>16&255,x.O()>>>8&255,x.O()&255)},
gmw(){return this.gh3().b},
gEy(){var x=this.gh3(),w=x.k3
return A.Ks(A.bl(97,w.O()>>>16&255,w.O()>>>8&255,w.O()&255),x.k2)},
gdC(){return A.tZ(new C.cHo(this))},
gG2(){var x=A.G(this.p4).ok.at
x.toString
return x.bb(this.gh3().c)},
gG0(){return this.gh3().b},
gG1(){return D.aqs},
gFP(){return D.R9},
gFU(){return D.Ra},
gFp(){return D.R8},
gFQ(){return D.afx}}
C.aln.prototype={
by(d){this.h1(d)
$.lr.vy$.a.H(0,this.gA7())},
bl(){$.lr.vy$.a.T(0,this.gA7())
this.fU()}}
C.alp.prototype={
by(d){this.h1(d)
$.lr.vy$.a.H(0,this.gA7())},
bl(){$.lr.vy$.a.T(0,this.gA7())
this.fU()}}
C.alx.prototype={
co(){this.cR()
this.cP()
this.fX()},
t(){var x=this,w=x.bZ$
if(w!=null)w.a7(x.gfM())
x.bZ$=null
x.aA()}}
C.bBH.prototype={}
C.bBI.prototype={}
C.aVs.prototype={
a54(d,e,f,g,h){var x,w,v,u,t,s,r=h.cy.U9(e,d).a
h.CW.toString
x=h.a
x.toString
if(J.p(h.b,B.ad)&&J.p(h.c,B.ad))w=0
else w=x
x=h.ok==null
v=x?Math.max(24,r/2):0
u=f.a+v
t=f.b+(g.gW().b-w)/2
v=g.gW()
x=x?Math.max(r,48):0
s=u+v.a-x
return new A.as(Math.min(u,s),t,Math.max(u,s),t+w)},
aOw(d,e,f){return this.a54(d,!1,B.W,e,f)},
aOx(d,e,f,g){return this.a54(d,!1,e,f,g)}}
C.btd.prototype={
bPH(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=a7.a
if(d==null||d<=0)return
$.b_()
x=A.bQ()
w=new A.jd(a7.e,a7.b).aI(a2.gA())
w.toString
x.r=w.gA()
v=A.bQ()
w=new A.jd(a7.r,a7.c).aI(a2.gA())
w.toString
v.r=w.gA()
switch(a8.a){case 1:w=new A.be(x,v)
break
case 0:w=new A.be(v,x)
break
default:w=null}u=w.a
t=null
s=w.b
t=s
r=this.a54(a3,a4,a1,a5,a7)
w=r.d
q=r.b
p=w-q
o=p/2
n=new A.c4(o,o)
p=(p+2)/2
m=new A.c4(p,p)
l=a8===B.bV
k=a8===B.dP
p=a9.a
o=r.c
d/=2
if(p<o-d){j=a0.gdY()
i=k?q-1:q
h=k?w+1:w
g=l?n:m
j.fQ(A.awH(p-d,i,o,h,g),t)}o=r.a
if(p>o+d){j=a0.gdY()
i=l?q-1:q
h=l?w+1:w
g=l?m:n
j.fQ(A.awH(o,i,p+d,h,g),u)}if(a6!=null){d=a6.a
f=l?d>p:d<p}else f=!1
if(f){e=A.bQ()
d=new A.jd(a7.f,a7.d).aI(a2.gA())
d.toString
e.r=d.gA()
d=a6.a
if(l)a0.gdY().fQ(A.NF(p,q,d,w,B.aW,n,B.aW,n),e)
else a0.gdY().fQ(A.NF(d,q,p,w,n,B.aW,n,B.aW),e)}},
gbMC(){return!0}}
C.btc.prototype={
a55(d,e){var x=this.a
if(x==null){x=e.a
x.toString
x/=4}x*=2
return new A.am(x,x)},
bPI(d,e,f,g,h,i,j,k){var x,w,v,u,t,s,r,q,p=e.a-k.a
A:{x=B.bV===j
if(x&&p>0){w=new A.be(i.z,i.x)
break A}v=B.dP===j
if(v&&p<0){w=new A.be(i.z,i.x)
break A}if(!x)w=v
else w=!0
if(w){w=new A.be(i.y,i.w)
break A}w=null}u=w.a
t=null
s=w.b
t=s
$.b_()
r=A.bQ()
w=new A.jd(u,t).aI(f.gA())
w.toString
r.r=w.gA()
q=this.a55(g,i).a/2
if(q>0)d.gdY().ju(e,q,r)}}
C.btb.prototype={
U9(d,e){return new A.am(20,20)},
a3_(d,e,f,g,h,i,j,k,l,m,n,o){var x,w,v,u=d.gdY(),t=y.t,s=new A.jd(l.at,l.Q).aI(g.gA())
s.toString
x=new A.bF(10,10,t).aI(g.gA())
w=new A.bF(1,6,t).aI(f.gA())
v=new A.ea($.b_().r,B.bN,null,null,A.a([],y.v))
t=2*x
v.bB(new A.Aa(A.VT(e,t,t),0,6.283185307179586))
u.afw(v,B.a0,w,!0)
t=A.bQ()
t.r=s.gA()
u.ju(e,x,t)}}
C.b0u.prototype={
a3_(d,e,f,g,h,i,j,k,l,m,n,o){var x=d.gdY(),w=f.gA(),v=l.ay
v.toString
D.arD.ahS(v,x,e,i,j,w,k,l.ch,n)}}
C.c0o.prototype={
a4Y(d,e,f,g,h,i){var x=this.aC1(e,g),w=x/2,v=A.e4(f.cp(null),d).a,u=Math.max(0,w-v+8),t=h.a,s=Math.max(0,w-(t-v-8))
if(x<t)return u-s
else{w=8*i
if(u-s>0)return u-w
else return-s+w}},
aC1(d,e){return(Math.max(20,d.b.c)+8)*e},
ahS(d,e,f,g,h,i,j,k,l){var x,w,v,u,t,s,r,q,p,o
if(i===0)return
x=this.aC1(g,i)
w=this.a4Y(f,g,h,i,j,l)
v=-x/2+w
u=new A.as(v,-34,v+x,-6)
v=$.b_()
t=A.bQ()
t.r=d.gA()
s=e.a
J.bX(s.save())
s.translate(f.a,f.b-16)
e.C0(i,i)
r=u.giw()/2
q=A.rI(B.l6,A.a18(new A.c4(r,r)),1).hs(u)
p=new A.ea(v.r,B.bN,null,null,A.a([],y.v))
p.bB(new A.fA(-10,-10))
p.bB(new A.fA(10,-10))
p.bB(new A.Ax())
p.bB(new A.kq(q))
if(k!=null){o=A.bQ()
o.r=k.gA()
o.c=1
o.b=B.dI
e.kh(p,o)}e.kh(p,t)
s.translate(0,-36)
v=g.b
g.bq(e,new A.V(w,16).av(0,new A.V(v.c/2,v.a.c.gaS()/2)))
s.restore()}}
C.bte.prototype={}
C.aLh.prototype={}
C.HY.prototype={
U(){return"ShowValueIndicator."+this.b}}
C.bBF.prototype={}
C.bta.prototype={}
C.awV.prototype={
a3_(d,e,f,g,h,i,j,k,l,m,n,o){var x=d.gdY(),w=f.gA(),v=l.ay
v.toString
D.arS.ahS(v,x,e,i,j,w,k,l.ch,n)}}
C.csn.prototype={
a4Y(d,e,f,g,h,i){var x=this.azJ(e,g,i),w=x/2,v=A.e4(f.cp(null),d).a,u=Math.max(0,w-v+8),t=h.a,s=Math.max(0,w-(t-v-8))
if(x<t)return u-s
else{w=8*i
if(u-s>0)return u-w
else return-s+w}},
azJ(d,e,f){return(Math.max(16*f,d.b.c)+32)*e},
ahS(d,e,f,g,h,i,j,k,l){var x,w,v,u,t,s,r,q,p
if(i===0)return
x=this.azJ(g,i,l)
w=this.a4Y(f,g,h,i,j,l)
v=g.b.a.c.gaS()+16
u=-x/2+w
t=-8-v
s=t+v
r=new A.ea($.b_().r,B.bN,null,null,A.a([],y.v))
r.bB(new A.fA(-8,-8))
r.bB(new A.fA(8,-8))
r.bB(new A.Ax())
q=A.bQ()
q.r=d.gA()
r.bB(new A.kq(A.p0(new A.as(u,t,u+x,s),B.n3)))
u=e.a
J.bX(u.save())
u.translate(f.a,f.b-14)
e.C0(i,i)
if(k!=null){p=A.bQ()
p.r=k.gA()
p.c=1
p.b=B.dI
e.kh(r,p)}e.kh(r,q)
t=s-t
u.translate(0,-8-t)
s=g.b
g.bq(e,new A.V(w,t/2).av(0,new A.V(s.c/2,s.a.c.gaS()/2)))
u.restore()}}
C.H8.prototype={
a6(){var x=A.N(["Logo",!0,"Org Name",!0,"Address",!0,"Contact",!0,"Tagline",!1,"Receipt #",!0,"Date",!0,"Student Name",!0,"Terms",!0,"Signature",!0,"Seat Number",!0,"Plan Name",!0,"Valid From",!0,"Valid To",!0,"Next Due Date",!1,"Payment Method",!0,"Security Deposit",!0],y.N,y.cB),w=$.ax()
return new C.ahh(x,new A.aA(new A.b9("REC",B.ar,B.ai),w),new A.aA(B.as,w),new A.aA(new A.b9("Thank you for your payment! \ud83d\udcda",B.ar,B.ai),w),B.iP)}}
C.ahh.prototype={
au(){this.aE()
this.Oe()},
t(){var x=this,w=x.x,v=w.X$=$.ax()
w.Z$=0
w=x.y
w.X$=v
w.Z$=0
w=x.z
w.X$=v
w.Z$=0
x.aA()},
Oe(){var x=0,w=A.o(y.H),v,u=2,t=[],s=[],r=this,q,p,o,n,m,l,k,j,i,h
var $async$Oe=A.j(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:l=r.gV()
k=$.aF()
j=y.T
i=l.G(k,j)
if(i==null||i.length===0){p=l.G($.cF(),y.P).gA()
i=p==null?null:p.a}x=i==null||i.length===0?3:4
break
case 3:x=5
return A.d(A.hg(B.ip,null,y.z),$async$Oe)
case 5:k=l.G(k,j)
if(k==null){l=l.G($.cF(),y.P).gA()
l=l==null?null:l.a
o=l}else o=k
i=o==null?A.dp():o
case 4:if(i.length===0){r.u(new C.coT(r))
x=1
break}u=7
l=$.h
n=(l==null?$.h=$.M():l).D("[DEFAULT]")
A.H(n,$.a9(),!0)
x=10
return A.d(A.a4(new A.L(n)).n("libraries").v(i).n("settings").v("receipt_template").a_(),$async$Oe)
case 10:q=e
if(q.gb2()&&r.c!=null){l=q.I()
r.anG(l==null?A.I(y.N,y.z):l)}s.push(9)
x=8
break
case 7:u=6
h=t.pop()
s.push(9)
x=8
break
case 6:s=[2]
case 8:u=2
if(r.c!=null)r.u(new C.coU(r))
x=s.pop()
break
case 9:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$Oe,w)},
anG(d){this.u(new C.coS(this,d))},
HZ(d,e,f){return this.boI(d,e,f)},
boI(d,e,f){var x=0,w=A.o(y.N),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j
var $async$HZ=A.j(function(g,h){if(g===1){t.push(h)
x=u}for(;;)switch(x){case 0:k=f
try{s=A.QF(f)
if(s!=null){r=s
if(r.gbC()>300||r.gaS()>300){p=r
o=r.gbC()>=r.gaS()?300:null
r=A.Jk(p,r.gaS()>r.gbC()?300:null,B.wv,o)}k=new Uint8Array(A.co(A.aRs(r,9)))
if(J.ac(k)>102400){r=A.Jk(r,220,B.wv,220)
k=new Uint8Array(A.co(A.aRs(r,9)))}}}catch(i){k=f}u=4
p=$.h
m=(p==null?$.h=$.M():p).D("[DEFAULT]")
A.H(m,$.a9(),!0)
p=C.dIQ(new A.L(m))
o=p.c
if(o==null){o=$.daj
if(o==null){o=$.aS0()
l=new C.a5W(12e4,6e5,6e5,null,"")
$.e8().j(0,l,o)
$.daj=l
o=l}o=p.c=o.aFj(p.d,p.e)}p=C.a8e(p,o.aiB("/"))
o=p.a
q=C.a8e(p.b,o.b.aiB(o.a.bCB("libraries/"+d+"/receipt_template/"+e+".png")))
o=q
p=k
l=o.b
o=o.a.aic(p,o.bzs(new A.WA(null,null,null,null,"image/png",null)))
A.H(o,$.d83(),!0)
x=7
return A.d(new C.aAU(o,l),$async$HZ)
case 7:x=8
return A.d(q.a.t1(),$async$HZ)
case 8:l=h
v=l
x=1
break
u=2
x=6
break
case 4:u=3
j=t.pop()
p=k
v="data:image/png;base64,"+B.f8.gj6().bI(p)
x=1
break
x=6
break
case 3:x=2
break
case 6:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$HZ,w)},
Da(){var x=0,w=A.o(y.H),v,u=2,t=[],s=[],r=this,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$Da=A.j(function(d,a0){if(d===1){t.push(a0)
x=u}for(;;)switch(x){case 0:g=r.gV()
f=g.G($.aF(),y.T)
if(f==null){g=g.G($.cF(),y.P).gA()
g=g==null?null:g.a
i=g}else i=f
q=i==null?A.dp():i
if(J.ac(q)===0){x=1
break}g=r.c
g.toString
x=3
return A.d(A.dP(null,new C.coZ(r),g,!1,null,!1,!1,y.b),$async$Da)
case 3:p=a0
if(p==null){x=1
break}r.u(new C.cp_(r))
$.jE=!0
u=5
o=new A.FS()
x=8
return A.d(o.SN(80,800,p),$async$Da)
case 8:n=a0
if(n==null||r.c==null){s=[1]
x=6
break}x=9
return A.d(n.jj(),$async$Da)
case 9:m=a0
l=A.baT(m,220)
x=10
return A.d(r.HZ(q,"stamp",l),$async$Da)
case 10:k=a0
if(r.c!=null){r.u(new C.cp0(r,k))
g=r.c
g.toString
A.anu(g,"\u2728 Stamp uploaded with transparent background! Remember to save settings.")}s.push(7)
x=6
break
case 5:u=4
e=t.pop()
j=A.aa(e)
g=r.c
if(g!=null)A.Rb(g,j)
s.push(7)
x=6
break
case 4:s=[2]
case 6:u=2
$.jE=!1
$.qD=new A.ad(Date.now(),0,!1)
$.pM=null
A.qE()
if(r.c!=null)r.u(new C.cp1(r))
x=s.pop()
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$Da,w)},
Db(){var x=0,w=A.o(y.H),v,u=2,t=[],s=[],r=this,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0
var $async$Db=A.j(function(a1,a2){if(a1===1){t.push(a2)
x=u}for(;;)switch(x){case 0:e=r.gV()
d=e.G($.aF(),y.T)
if(d==null){d=e.G($.cF(),y.P).gA()
d=d==null?null:d.a
i=d}else i=d
q=i==null?A.dp():i
if(J.ac(q)===0){x=1
break}e=e.G($.cF(),y.P).gA()
h=e==null?null:e.d
e=r.c
e.toString
x=3
return A.d(A.dP(null,new C.cp7(r,h),e,!1,null,!1,!1,y.N),$async$Db)
case 3:g=a2
if(g==null){x=1
break}if(g==="use_library_logo"&&h!=null){e={}
e.a=h
if(B.d.aN(h,"data:image")||h.length>2000)e.a=r.a7G(h,250)
if(r.c!=null){r.u(new C.cp8(e,r))
e=r.c
e.toString
A.anu(e,"\u2728 Set library profile logo as watermark! Remember to save settings.")}x=1
break}p=g==="camera"?B.iw:B.j5
r.u(new C.cp9(r))
$.jE=!0
u=5
o=new A.FS()
x=8
return A.d(o.SN(80,800,p),$async$Db)
case 8:n=a2
if(n==null||r.c==null){s=[1]
x=6
break}x=9
return A.d(n.jj(),$async$Db)
case 9:m=a2
l=A.baT(m,235)
x=10
return A.d(r.HZ(q,"watermark",l),$async$Db)
case 10:k=a2
if(r.c!=null){r.u(new C.cpa(r,k))
e=r.c
e.toString
A.anu(e,"\u2728 Background watermark uploaded with transparent background! Remember to save settings.")}s.push(7)
x=6
break
case 5:u=4
a0=t.pop()
j=A.aa(a0)
e=r.c
if(e!=null)A.Rb(e,j)
s.push(7)
x=6
break
case 4:s=[2]
case 6:u=2
$.jE=!1
$.qD=new A.ad(Date.now(),0,!1)
$.pM=null
A.qE()
if(r.c!=null)r.u(new C.cpb(r))
x=s.pop()
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$Db,w)},
a7G(d,e){var x,w,v,u,t,s,r,q,p
try{x=B.d.k(d,",")?d.split(",")[1]:d
r=J.DG(x)
r=A.aw(r,"\n","")
w=A.aw(r,"\r","")
v=B.fg.bI(w)
u=A.QF(v)
if(u==null)return d
t=u
if(t.gbC()>e||t.gaS()>e){r=t
q=t.gbC()>=t.gaS()?e:null
t=A.Jk(r,t.gaS()>t.gbC()?e:null,B.wv,q)}s=new Uint8Array(A.co(A.aRs(t,9)))
if(J.ac(s)>61440){t=A.Jk(t,180,B.wv,180)
s=new Uint8Array(A.co(A.aRs(t,9)))}r=s
r=B.f8.gj6().bI(r)
return"data:image/png;base64,"+r}catch(p){return d}},
Ie(){var x=0,w=A.o(y.H),v,u=2,t=[],s=[],r=this,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$Ie=A.j(function(a5,a6){if(a5===1){t.push(a6)
x=u}for(;;)switch(x){case 0:a1=r.gV()
a2=a1.G($.aF(),y.T)
if(a2==null||a2.length===0){i=a1.G($.cF(),y.P).gA()
h=i==null?null:i.a
a2=h==null?A.dp():h}if(a2.length===0){x=1
break}r.u(new C.cpe(r))
u=4
q=r.ch
if(q!=null&&q.length!==0){if(B.d.aN(q,"data:image")||q.length>2000){q=r.a7G(q,250)
r.ch=q}if(q.length>256e3){q=""
r.ch=null}}p=r.as
if(p!=null&&p.length!==0){if(B.d.aN(p,"data:image")||p.length>2000){p=r.a7G(p,250)
r.as=p}if(p.length>256e3){p=""
r.as=null}}g=B.d.q(r.x.a.a)
o=g.length===0?"REC":g
i=y.N
f=y.z
n=A.cS(r.w,i,f)
J.U(n,"prefix",o)
J.U(n,"customTerms",B.d.q(r.y.a.a))
J.U(n,"footerText",B.d.q(r.z.a.a))
e=p
if(e==null)e=""
J.U(n,"stampUrl",e)
J.U(n,"stampEnabled",r.at)
J.U(n,"stampRotation",r.ax)
J.U(n,"stampScale",r.ay)
e=q
if(e==null)e=""
J.U(n,"watermarkUrl",e)
J.U(n,"watermarkEnabled",r.CW)
J.U(n,"watermarkOpacity",r.cx)
J.U(n,"watermarkScale",r.cy)
J.U(n,"headerFontSize",r.db)
J.U(n,"receiptStyle",r.dx)
J.U(n,"pageSize",r.dy)
J.U(n,"fontFamily",r.fr)
J.U(n,"primaryColor",B.d.bj(B.d.dd(B.j.fR(r.fx.O(),16),8,"0"),2).toUpperCase())
m=n
n=$.h
d=(n==null?$.h=$.M():n).D("[DEFAULT]")
A.H(d,$.a9(),!0)
n=A.a4(new A.L(d)).n("libraries").v(a2).n("settings").v("receipt_template")
l=A.cS(m,i,f)
f=$.b1().ak()
J.U(l,"updatedAt",new A.aj(f,f))
f=A.dz(!0)
l=A.dH(l)
l.toString
x=7
return A.d(n.a.ba(l,f),$async$Ie)
case 7:u=9
x=12
return A.d(A.cr(),$async$Ie)
case 12:k=a6
x=13
return A.d(k.bd("String","cached_receipt_template_"+a2,B.cb.ki(m,null)),$async$Ie)
case 13:u=4
x=11
break
case 9:u=8
a3=t.pop()
x=11
break
case 8:x=4
break
case 11:r.Q=!1
a1.c0($.aSn())
n=r.c
if(n!=null)n.M(y.q).f.a2(D.cg6)
s.push(6)
x=5
break
case 4:u=3
a4=t.pop()
j=A.aa(a4)
n=r.c
if(n!=null)n.M(y.q).f.a2(A.aV(null,null,null,null,null,B.z,null,A.c("Error saving template: "+A.q(j),null,null,null,null,null,null,null,null),null,B.L,null,null,null,null,null,null,null,null,null,null))
s.push(6)
x=5
break
case 3:s=[2]
case 5:u=2
if(r.c!=null)r.u(new C.cpf(r))
x=s.pop()
break
case 6:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$Ie,w)},
OF(){var x=0,w=A.o(y.H),v=1,u=[],t=this,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6,a7
var $async$OF=A.j(function(a8,a9){if(a8===1){u.push(a9)
x=v}for(;;)switch(x){case 0:d=t.gV().G($.cF(),y.P).gA()
a0=d==null?A.db3(4280171146,"Station Road, City Centre","","","",B.LH,"+91 9800000000",new A.ad(Date.now(),0,!1),"",!1,B.CQ,B.j6,"","",18,"","+91 9800000000","preview_lib",null,null,"","","","CC","Study Library Center","6 AM - 11 PM","","preview_admin","",null,"",B.Ck,7,"Maintain silence.","999293",10,B.fD,"","en",new A.ad(Date.now(),0,!1),"",!0,24,B.y3,"","Your Peaceful Study Haven","","","","","","",""):d
a1=A.azU(null,"Main Street, Parli",null,null,null,"City College","Pharmacy",new A.ad(Date.now(),0,!1),null,B.iy,null,null,null,null,null,"ashish@example.com","+91 73858 17571","Wagesh Choudhari",null,null,null,B.iq,null,null,"","XXXX-XXXX-1234",null,null,B.dj,null,!1,"CC20260002",null,!1,!1,!1,!1,null,null,null,null,"CC20260002",B.cH,"Ashish Wagesh Choudhari",null,null,null,"+91 73858 17571","",!1,"431515",null,null,null,null,null,null,B.ak,null,null,null,"seat_2",null,null,null,null,null,null,0,"Completed")
a2=A.uR(null,null,null,null,"AC Study Hall Access \u2022 Reserved Desk \u2022 High-Speed Wi-Fi \u2022 Power Backup",1,1,B.eG,3,!1,"PLAN-001",!0,!1,a0.a,"Monthly Dedicated Seat Plan",null,1500,null,null)
a3=t.w
a4=a3.h(0,"Security Deposit")
a5=a4!==!1
a6=B.d.q(t.x.a.a)
a4=(a6.length!==0?a6:"REC")+"-"
n=Date.now()
m=a0.a
l=Date.now()
k=a1.a
j=a2.a
i=a5?1500:1000
h=a5?500:null
g=Date.now()
f=new A.ad(Date.now(),0,!1).d8(2592e9)
s=A.tw(i,null,new A.ad(Date.now(),0,!1),B.iy,null,null,null,null,a4+A.bz(new A.ad(n,0,!1))+"-0001",null,null,!1,!1,m,null,"UPI",null,j,a4+A.bz(new A.ad(l,0,!1))+"-0001",null,null,h,null,B.hh,k,null,null,null,null,new A.ad(g,0,!1),f)
v=3
r=A.cS(a3,y.N,y.X)
J.U(r,"customTerms",B.d.q(t.y.a.a))
J.U(r,"stampUrl",t.as)
J.U(r,"stampEnabled",t.at)
J.U(r,"stampRotation",t.ax)
J.U(r,"stampScale",t.ay)
J.U(r,"watermarkUrl",t.ch)
J.U(r,"watermarkEnabled",t.CW)
J.U(r,"watermarkOpacity",t.cx)
J.U(r,"watermarkScale",t.cy)
J.U(r,"headerFontSize",t.db)
J.U(r,"receiptStyle",t.dx)
J.U(r,"pageSize",t.dy)
J.U(r,"fontFamily",t.fr)
J.U(r,"primaryColor",B.d.bj(B.d.dd(B.j.fR(t.fx.O(),16),8,"0"),2).toUpperCase())
J.U(r,"footerText",B.d.q(t.z.a.a))
q=r
x=6
return A.d(new A.BC().aNs(s,a1,a2,a0,q,"12"),$async$OF)
case 6:p=a9
x=7
return A.d(A.bnT(!0,B.od,"Fee_Receipt_Sample.pdf",new C.cpd(p),!1),$async$OF)
case 7:v=1
x=5
break
case 3:v=2
a7=u.pop()
o=A.aa(a7)
r=t.c
if(r!=null)r.M(y.q).f.a2(A.aV(null,null,null,null,null,B.z,null,A.c("Could not generate preview: "+A.q(o),null,null,null,null,null,null,null,null),null,B.L,null,null,null,null,null,null,null,null,null,null))
x=5
break
case 2:x=1
break
case 5:return A.m(null,w)
case 1:return A.l(u.at(-1),w)}})
return A.n($async$OF,w)},
P(d6){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7=this,c8=null,c9="Seat Number",d0="Signature",d1=A.G(d6),d2=c7.gV(),d3=d2.a4($.cF(),y.P).gA(),d4=d3==null,d5=d4?c8:d3.d
if(d5==null)d5=""
x=c7.ch
x=x!=null&&x.length!==0?x:d5
d2.nE($.aSn(),new C.cpI(c7),y.U)
if(c7.fy)return A.cf(A.cu(c8,c8,c8,!0,!0,c8,c8,1,c8,c8,c8,!1,c8,!1,c8,c8,c8,c8,!0,c8,c8,c8,c8,c8,D.ajV,c8,c8,c8,1,c8,!0),c8,B.ba,c8,!1,c8,c8)
d2=c7.gboD()
w=A.aK(c8,c8,c8,B.wq,c8,c8,d2,c8,c8,c8,"Preview PDF Receipt",c8)
v=c7.go
u=v?B.iC:B.pY
t=y.p
u=A.cu(A.a([w,A.aK(c8,c8,c8,u,c8,c8,v?c8:c7.gayh(),c8,c8,c8,"Save Settings",c8)],t),c8,c8,!0,!0,c8,c8,1,c8,c8,c8,!1,c8,!1,c8,c8,c8,c8,!0,c8,c8,c8,c8,c8,D.ajV,c8,c8,c8,1,c8,!0)
s=A.G(d6)
r=(d4?c8:B.d.q(d3.b).length!==0)===!0?B.d.q(d3.b):"The Cozy Corner Study Centre"
q=d4?c8:d3.d
if(q==null)q=""
p=(d4?c8:B.d.q(d3.c).length!==0)===!0?B.d.q(d3.c):"Station Road, City Centre"
if(d4)w=c8
else{w=d3.e
w=B.d.q(w).length!==0}if(w===!0){w=d3.e
o=B.d.q(w)}else o="+91 98000 00000"
n=(d4?c8:B.d.q(d3.dy).length!==0)===!0?B.d.q(d3.dy):"Your Peaceful Study Haven"
d4=c7.x
w=B.d.q(d4.a.a)
m=w.length===0?"REC":w.toUpperCase()
w=Date.now()
v=c7.w
l=v.h(0,"Logo")
k=v.h(0,"Org Name")
j=v.h(0,"Address")
i=v.h(0,"Contact")
h=v.h(0,"Tagline")
g=v.h(0,"Receipt #")
f=v.h(0,"Date")
e=v.h(0,"Student Name")
d=v.h(0,c9)
a0=v.h(0,"Plan Name")
a1=v.h(0,"Valid From")
a2=v.h(0,"Payment Method")
a3=v.h(0,"Security Deposit")
a4=a3!==!1
a3=v.h(0,"Next Due Date")
a5=v.h(0,"Terms")
a6=v.h(0,d0)
a7=a6!==!1
a6=c7.z
a8=B.d.q(a6.a.a)
if(a8.length!==0)a9=A.aw(a8,"{libraryName}",r)
else a9="Thank you for choosing "+r
b0=c7.fx.p5()<0.45?B.B:B.cG
b1=c7.fx.m(0.08)
b2=c7.fx.m(0.35)
a8=A.i(16)
b3=A.Y(B.JN,c7.fx,c8,c8,18)
b4=s.ok.x
d2=A.u(A.a([b3,B.D,A.J(A.c("Live Instant Receipt Preview (A4)",1,B.Z,c8,c8,b4==null?c8:b4.b_(B.w),c8,c8,c8),1,c8),A.ep(B.YT,D.cHu,d2,A.f1(c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,B.ay))],t),B.k,B.f,B.i,0,c8,c8)
b3=A.i(12)
b4=A.a5(B.bD,1)
b5=y.V
b6=A.a([new A.b0(0,B.aa,B.a0.m(0.05),B.eg,10)],b5)
b7=A.i(12)
b8=A.a([],t)
if(c7.CW&&x.length!==0){b9=B.l.aa(c7.cx,0.02,0.35)
c0=B.l.aa(c7.cy,0.4,1.05)
b8.push(A.mk(0,A.aE(A.mi(A.Cy(B.a4,c7.awQ(x,150),c0,c8,c8,!0),b9),c8,c8)))}b9=A.a([],t)
if(l!==!1){l=A.i(8)
c0=A.a5(b2,1)
c1=q.length!==0?A.iL(A.i(7),c7.awR(q,B.d1,36),B.bO):A.Y(B.Jt,c7.fx,c8,c8,20)
B.h.B(b9,A.a([A.w(c8,c1,B.n,c8,c8,new A.x(b1,c8,c0,l,c8,c8,B.u),c8,36,c8,c8,c8,c8,c8,36),B.al],t))}l=A.a([],t)
if(k!==!1)l.push(A.c(r.toUpperCase(),1,B.Z,c8,c8,c7.mX(c7.fx,B.l.aa(c7.db*0.56,11,16),B.b2),c8,c8,c8))
if(h===!0)l.push(A.c(n,c8,c8,c8,c8,c7.boB(B.bA,8.5,B.fl),c8,c8,c8))
if(j!==!1)l.push(A.c(p,1,B.Z,c8,c8,c7.HX(B.av,8.5),c8,c8,c8))
if(i!==!1)l.push(A.c("Helpline: "+o,c8,c8,c8,c8,c7.mX(B.bA,8.5,B.a1),c8,c8,c8))
b9.push(A.J(A.z(l,B.x,c8,B.f,B.i,0,B.o),1,c8))
l=A.i(12)
k=A.a5(b2,1)
b9.push(A.z(A.a([A.w(c8,A.c("\u2022 PAYMENT CONFIRMED",c8,c8,c8,c8,c7.mX(c7.fx,7.5,B.w),c8,c8,c8),B.n,c8,c8,new A.x(b1,c8,k,l,c8,c8,B.u),c8,c8,c8,c8,B.vN,c8,c8,c8),B.aL,A.c("ORIGINAL STUDENT COPY",c8,c8,c8,c8,c7.mX(B.dX,6.5,B.w),c8,c8,c8)],t),B.eU,c8,B.f,B.i,0,B.o))
b9=A.u(b9,B.x,B.f,B.i,0,c8,c8)
l=A.ut(b2,c8,14,c8,c8)
k=A.i(6)
j=A.a5(b2,1)
i=A.a([A.c("RECEIPT INFO",c8,c8,c8,c8,c7.mX(c7.fx,7,B.w),c8,c8,c8),B.db],t)
if(g!==!1)i.push(A.c("No: "+(m+"-"+A.bz(new A.ad(w,0,!1))+"-0001"),c8,c8,c8,c8,c7.mX(B.bC,8,B.w),c8,c8,c8))
if(f!==!1)i.push(A.c("Date: 28 Nov 2026",c8,c8,c8,c8,c7.HX(B.bC,8),c8,c8,c8))
if(a2!==!1)i.push(A.c("Mode: UPI",c8,c8,c8,c8,c7.mX(c7.fx,8,B.w),c8,c8,c8))
w=A.J(A.w(c8,A.z(i,B.x,c8,B.f,B.i,0,B.o),B.n,c8,c8,new A.x(c8,c8,j,k,c8,c8,B.u),c8,c8,c8,c8,B.rt,c8,c8,c8),1,c8)
k=A.i(6)
j=A.a5(b2,1)
i=A.a([A.c("STUDENT & DESK",c8,c8,c8,c8,c7.mX(c7.fx,7,B.w),c8,c8,c8),B.db],t)
if(e!==!1)i.push(A.c("Sample Student",c8,c8,c8,c8,c7.mX(B.bC,8,B.w),c8,c8,c8))
if(d!==!1)i.push(A.c("Seat #12",c8,c8,c8,c8,c7.mX(c7.fx,8,B.w),c8,c8,c8))
w=A.u(A.a([w,B.D,A.J(A.w(c8,A.z(i,B.x,c8,B.f,B.i,0,B.o),B.n,c8,c8,new A.x(c8,c8,j,k,c8,c8,B.u),c8,c8,c8,c8,B.rt,c8,c8,c8),1,c8)],t),B.x,B.f,B.i,0,c8,c8)
k=A.i(6)
j=A.a5(B.bD,1)
i=c7.fx
i=A.w(c8,A.u(A.a([A.J(A.c("PLAN / SERVICE",c8,c8,c8,c8,c7.mX(b0,7,B.w),c8,c8,c8),1,c8),A.c("AMOUNT",c8,c8,c8,c8,c7.mX(b0,7,B.w),c8,c8,c8)],t),B.k,B.f,B.i,0,c8,c8),B.n,i,c8,c8,c8,c8,c8,c8,B.ru,c8,c8,c8)
h=a0!==!1?"Monthly Dedicated Seat Plan":"Library Membership"
h=A.a([A.c(h,c8,c8,c8,c8,c7.mX(B.bC,9.5,B.w),c8,c8,c8)],t)
if(a1!==!1)h.push(A.c("Valid: 01 Dec \u2013 31 Dec 2026",c8,c8,c8,c8,c7.HX(B.bA,8),c8,c8,c8))
if(a4)h.push(A.c("+ Security Deposit: \u20b9500",c8,c8,c8,c8,c7.HX(B.bA,8),c8,c8,c8))
if(a3===!0)h.push(A.c("Next Due: 01 Jan 2027",c8,c8,c8,c8,c7.mX(c7.fx,8,B.a1),c8,c8,c8))
h=A.J(A.z(h,B.x,c8,B.f,B.i,0,B.o),1,c8)
g=c7.fx
f=A.i(6)
e=a4?"\u20b91,500":"\u20b91,000"
k=A.w(c8,A.z(A.a([i,new A.T(D.aD3,A.u(A.a([h,A.w(c8,A.c(e,c8,c8,c8,c8,c7.mX(b0,10.5,B.b2),c8,c8,c8),B.n,c8,c8,new A.x(g,c8,c8,f,c8,c8,B.u),c8,c8,c8,c8,B.cW,c8,c8,c8)],t),B.k,B.au,B.i,0,c8,c8),c8)],t),B.k,c8,B.f,B.i,0,B.o),B.bO,c8,c8,new A.x(c8,c8,j,k,c8,c8,B.u),c8,c8,c8,c8,c8,c8,c8,c8)
j=A.a([],t)
if(a5!==!1){i=B.d.q(c7.y.a.a)
i=i.length!==0?i:"\u2022 Fees once paid are non-refundable."
j.push(A.c(i,2,B.Z,c8,c8,c7.HX(B.bA,7.8),c8,c8,c8))}j.push(B.aL)
j.push(A.c(a9,1,B.Z,c8,c8,c7.mX(c7.fx,8,B.a1),c8,c8,c8))
j=A.a([A.J(A.z(j,B.x,c8,B.f,B.i,0,B.o),1,c8)],t)
if(c7.at||a7){i=A.a([],t)
if(c7.at){h=c7.as
h=h!=null&&h.length!==0}else h=!1
if(h){h=c7.ax
g=B.l.aa(c7.ay*0.55,0.35,0.9)
f=c7.as
f.toString
i.push(A.Xs(h*3.14159/180,A.Cy(B.a4,c7.awQ(f,42),g,c8,c8,!0)))}if(a7)B.h.B(i,A.a([B.am,A.z(A.a([A.w(c8,c8,B.n,B.dX,c8,c8,c8,1,c8,c8,c8,c8,c8,56),B.aL,A.c("Authorized",c8,c8,c8,c8,c7.HX(B.bA,7.5),c8,c8,c8)],t),B.k,c8,B.f,B.i,0,B.o)],t))
B.h.B(j,A.a([B.D,A.u(i,B.k,B.f,B.C,0,c8,c8)],t))}b8.push(new A.T(B.bR,A.z(A.a([b9,l,w,B.N,k,B.N,A.u(j,B.eU,B.au,B.i,0,c8,c8)],t),B.x,c8,B.f,B.i,0,B.o),c8))
d2=A.bO(new A.T(B.bR,A.z(A.a([d2,B.af,A.w(c8,A.iL(b7,new A.d_(B.bX,c8,B.bm,B.z,b8,c8),B.bO),B.n,c8,c8,new A.x(B.B,c8,b4,b3,b6,c8,B.u),c8,c8,c8,c8,c8,c8,c8,1/0)],t),B.x,c8,B.f,B.i,0,B.o),c8),c8,c8,0,c8,c8,new A.at(a8,new A.aI(b2,1.4,B.S,-1)))
w=A.i(16)
l=d1.ax
k=l.to
j=k==null
if(j){i=l.C
if(i==null)i=l.k3}else i=k
i=i.m(0.6)
h=l.d
g=h==null
f=g?l.b:h
e=A.i(10)
d=l.e
a0=d==null
f=A.w(c8,A.Y(D.aJ1,a0?l.c:d,c8,c8,20),B.n,c8,c8,new A.x(f,c8,c8,e,c8,c8,B.u),c8,c8,c8,c8,B.aK,c8,c8,c8)
e=d1.ok
a1=e.w
a2=a1==null
a3=A.c("Layout & Branding Identity",1,B.Z,c8,c8,a2?c8:a1.b_(B.w),c8,c8,c8)
a5=e.Q
a8=a5==null
if(a8)b3=c8
else{b3=l.ry
if(b3==null){b3=l.C
if(b3==null)b3=l.k3}b3=a5.bb(b3)}b3=A.u(A.a([f,B.a3,A.J(A.z(A.a([a3,A.c("Receipt architecture, paper standard and brand accent",2,B.Z,c8,c8,b3,c8,c8,c8)],t),B.x,c8,B.f,B.i,0,B.o),1,c8)],t),B.k,B.f,B.i,0,c8,c8)
a3=l.RG
f=a3==null
b4=(f?l.k2:a3).m(0.4)
b6=A.i(12)
if(j){b7=l.C
if(b7==null)b7=l.k3}else b7=k
b7=A.a5(b7.m(0.7),1)
b8=g?l.b:h
b9=A.i(10)
b8=A.w(c8,A.Y(B.de,a0?l.c:d,c8,c8,22),B.n,c8,c8,new A.x(b8,c8,c8,b9,c8,c8,B.u),c8,c8,c8,c8,B.cp,c8,c8,c8)
e=e.x
b9=e==null
c0=A.J(A.c("Modern Business Standard",1,B.Z,c8,c8,b9?c8:e.b_(B.w),c8,c8,c8),1,c8)
c1=B.V.m(0.15)
c2=A.i(10)
c2=A.u(A.a([c0,B.D,A.w(c8,D.cz4,B.n,c8,c8,new A.x(c1,c8,A.a5(B.V.m(0.35),1),c2,c8,c8,B.u),c8,c8,c8,c8,B.fU,c8,c8,c8)],t),B.k,B.f,B.i,0,c8,c8)
if(a8)c0=c8
else{c0=l.rx
c0=a5.nj(c0==null?l.k3:c0,1.35)}b6=A.w(c8,A.u(A.a([b8,B.a3,A.J(A.z(A.a([c2,B.aJ,A.c("Universal institutional invoice format: 2-column metadata, itemized fee table with seat & validity badges, balance due status, digital stamp, watermark, and QR verification. Standardized for A4 paper and high-clarity PDF sharing via WhatsApp.",c8,c8,c8,c8,c0,c8,c8,c8)],t),B.x,c8,B.f,B.i,0,B.o),1,c8)],t),B.x,B.f,B.i,0,c8,c8),B.n,c8,c8,new A.x(b4,c8,b7,b6,c8,c8,B.u),c8,c8,c8,c8,B.bR,c8,c8,c8)
b4=A.c("Receipt Number Prefix",c8,c8,c8,c8,b9?c8:e.b_(B.w),c8,c8,c8)
b7=B.d.q(d4.a.a)
if(b7.length===0)b7="REC"
b7=A.bU(c8,B.ak,!1,c8,!0,B.z,c8,A.bW(),d4,c8,c8,c8,c8,c8,2,A.ce(c8,B.a_,c8,c8,c8,c8,c8,c8,!0,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,"Sample generated number: "+b7+"-"+A.bz(new A.ad(Date.now(),0,!1))+"-0001",c8,c8,c8,c8,"e.g. REC, INV, CC",c8,c8,c8,c8,c8,c8,c8,c8,c8,!0,!0,!1,c8,B.td,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8),B.J,!0,c8,!0,c8,!1,c8,B.aB,c8,c8,c8,c8,c8,c8,c8,c8,1,c8,c8,!1,"\u2022",c8,new C.cpJ(c7),c8,c8,c8,!1,c8,c8,!1,c8,!0,c8,B.ag,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,!0,B.Q,c8,B.nb,c8,c8,c8,c8)
d4=A.c("Receipt Brand Accent Color",c8,c8,c8,c8,b9?c8:e.b_(B.w),c8,c8,c8)
b8=A.Z(new A.X(A.a([B.ky,B.iP,B.f9,B.bv,B.fP,B.p1,B.SE,B.Go],y.c),new C.cpK(c7),y.F),y.l)
b8.push(B.an)
c0=f?l.k2:a3
c1=A.i(20)
if(j){c2=l.C
if(c2==null)c2=l.k3}else c2=k
c2=A.a5(c2,1)
c3=c7.fx
b8.push(A.f9(c8,A.w(c8,A.u(A.a([A.Y(B.w2,c3,c8,c8,16),B.am,A.c("#"+B.d.bj(B.d.dd(B.j.fR(c3.O(),16),8,"0"),2).toUpperCase(),c8,c8,c8,c8,B.c2,c8,c8,c8)],t),B.k,B.f,B.C,0,c8,c8),B.n,c8,c8,new A.x(c0,c8,c2,c1,c8,c8,B.u),c8,c8,c8,c8,B.cw,c8,c8,c8),B.J,!1,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,new C.cpV(c7,d6),c8,c8,c8,c8,c8,c8,!1,B.c6))
b8=A.c0(A.u(b8,B.k,B.f,B.i,0,c8,c8),c8,B.J,c8,c8,c8,c8,B.ac)
c0=A.c("Receipt Typography & Font",c8,c8,c8,c8,b9?c8:e.b_(B.w),c8,c8,c8)
c1=B.a9Z.gdA()
i=A.bO(new A.T(B.e4,A.z(A.a([b3,B.fo,b6,B.P,b4,B.N,b7,B.P,d4,B.N,b8,B.P,c0,B.N,A.ca(B.a2,c1.dK(c1,new C.cpY(c7),y.a).cF(0),B.b6,B.a2,8,8)],t),B.x,c8,B.f,B.i,0,B.o),c8),c8,c8,0,c8,c8,new A.at(w,new A.aI(i,1,B.S,-1)))
w=A.i(16)
if(j){d4=l.C
if(d4==null)d4=l.k3}else d4=k
d4=d4.m(0.6)
b3=g?l.b:h
b4=A.i(10)
b3=A.w(c8,A.Y(B.iv,a0?l.c:d,c8,c8,20),B.n,c8,c8,new A.x(b3,c8,c8,b4,c8,c8,B.u),c8,c8,c8,c8,B.aK,c8,c8,c8)
b4=A.c("Official Stamp & Watermark",c8,c8,c8,c8,a2?c8:a1.b_(B.w),c8,c8,c8)
if(a8)b6=c8
else{b6=l.ry
if(b6==null){b6=l.C
if(b6==null)b6=l.k3}b6=a5.bb(b6)}b6=A.u(A.a([A.u(A.a([b3,B.a3,A.J(A.z(A.a([b4,A.c("Anti-counterfeiting security and authentication",c8,B.Z,c8,c8,b6,c8,c8,c8)],t),B.x,c8,B.f,B.i,0,B.o),1,c8)],t),B.k,B.f,B.i,0,c8,c8),A.Cn(c8,c8,c8,c8,!1,B.J,c8,c8,c8,c8,c8,c8,new C.cpZ(c7),c8,c8,c8,c8,c8,c8,c8,c8,c7.at)],t),B.k,B.au,B.i,0,c8,c8)
b3=c7.id?c8:c7.gawz()
b4=A.i(10)
b7=c7.as
b8=A.a5(b7!=null&&b7.length!==0?l.b.m(0.5):B.bD,1.5)
c0=A.i(10)
c1=A.a([],t)
b7=c7.as
if(b7!=null&&b7.length!==0){b7=A.i(9)
c2=B.l.aa(c7.ay,0.6,1.6)
c3=c7.ax
c4=c7.as
c4.toString
c1.push(A.iL(b7,A.Cy(B.a4,A.Xs(c3*3.14159/180,A.wr(c4,B.jV,c8,c8)),c2,c8,c8,!0),B.bO))}else c1.push(D.asz)
b7=l.b
c1.push(A.eb(4,A.w(c8,D.YD,B.n,c8,c8,new A.x(b7,c8,c8,c8,c8,c8,B.ap),c8,c8,c8,c8,B.hy,c8,c8,c8),c8,c8,c8,4,c8,c8))
b3=A.l8(A.bm(!1,b4,!0,A.w(c8,new A.d_(B.a4,c8,B.bm,B.z,c1,c8),B.n,c8,c8,new A.x(B.fQ,c8,b8,c0,c8,c8,B.u),c8,80,c8,c8,c8,c8,c8,80),c8,!0,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,b3,c8,c8,c8,c8,c8,c8,c8),c8,c8,"Click to upload or change stamp image",c8,c8,c8,c8,c8,c8)
b4=c7.id
b8=b4?c8:c7.gawz()
b4=b4?B.jO:D.aRn
c0=c7.as
b4=A.a([A.cj(b4,A.c(c0!=null&&c0.length!==0?"Change Stamp":"Upload Official Stamp",c8,c8,c8,c8,c8,c8,c8,c8),b8,c8)],t)
b8=c7.as
if(b8!=null&&b8.length!==0)B.h.B(b4,A.a([B.aJ,A.ca(B.a2,A.a([A.ep(E.Ki,D.ajC,c7.id?c8:new C.cq_(c7,d6),c8),A.ep(B.YP,D.cJG,new C.cq0(c7),c8)],t),B.b6,B.a2,4,8)],t))
b4.push(B.aL)
b8=c7.as
b4.push(A.c(b8!=null&&b8.length!==0?"Stamp will appear rotated "+B.l.L(c7.ax)+"\xb0 overlapping signature":"Upload library seal or stamp image to authenticate receipts",c8,c8,c8,c8,B.kZ,c8,c8,c8))
b3=A.a([b6,B.a9,A.u(A.a([b3,B.dr,A.J(A.z(b4,B.x,c8,B.f,B.i,0,B.o),1,c8)],t),B.x,B.f,B.i,0,c8,c8)],t)
if(c7.at){b4=g?b7:h
b6=A.i(6)
b8=B.l.L(c7.ax)
b4=A.u(A.a([D.ctu,B.c7,A.w(c8,A.c(""+b8+"\xb0",c8,c8,c8,c8,A.A(c8,c8,a0?l.c:d,c8,c8,c8,c8,c8,c8,c8,c8,12,c8,c8,B.w,c8,c8,!0,c8,c8,c8,c8,c8,c8,c8,c8),c8,c8,c8),B.n,c8,c8,new A.x(b4,c8,c8,b6,c8,c8,B.u),c8,c8,c8,c8,B.fV,c8,c8,c8)],t),B.k,B.f,B.i,0,c8,c8)
b6=B.l.aa(c7.ax,-45,45)
b6=C.bBE(90,""+B.l.L(c7.ax)+"\xb0",45,-45,new C.cq1(c7),b6)
b8=A.a([D.cwO,B.an],t)
for(c5=0;c5<4;++c5){c6=D.bLq[c5]
b8.push(new A.T(B.nG,A.h1(c8,c8,A.c(c6.b,c8,c8,c8,c8,B.ca,c8,c8,c8),c8,c8,new C.cq2(c7,c6),c8,Math.abs(c7.ax-c6.a)<1,c8,c8,B.ay),c8))}b8=A.c0(A.u(b8,B.k,B.f,B.i,0,c8,c8),c8,B.J,c8,c8,c8,c8,B.ac)
c0=g?b7:h
c1=A.i(6)
c2=B.l.L(c7.ay*100)
c0=A.u(A.a([D.cNY,B.c7,A.w(c8,A.c(""+c2+"%",c8,c8,c8,c8,A.A(c8,c8,a0?l.c:d,c8,c8,c8,c8,c8,c8,c8,c8,12,c8,c8,B.w,c8,c8,!0,c8,c8,c8,c8,c8,c8,c8,c8),c8,c8,c8),B.n,c8,c8,new A.x(c0,c8,c8,c1,c8,c8,B.u),c8,c8,c8,c8,B.fV,c8,c8,c8)],t),B.k,B.f,B.i,0,c8,c8)
c1=B.l.aa(c7.ay,0.6,1.6)
B.h.B(b3,A.a([B.a9,b4,b6,b8,B.af,c0,C.bBE(10,""+B.l.L(c7.ay*100)+"%",1.6,0.6,new C.cq3(c7),c1)],t))}b3.push(D.ayy)
b3.push(A.u(A.a([A.u(A.a([A.Y(B.WB,b7,c8,c8,18),B.D,D.cxI],t),B.k,B.f,B.i,0,c8,c8),A.Cn(c8,c8,c8,c8,!1,B.J,c8,c8,c8,c8,c8,c8,new C.cpL(c7),c8,c8,c8,c8,c8,c8,c8,c8,c7.CW)],t),B.k,B.au,B.i,0,c8,c8))
b3.push(B.aJ)
b3.push(D.cDN)
if(c7.CW){b4=c7.k1?c8:c7.gawA()
b6=A.i(10)
b8=x.length!==0
c0=A.a5(b8?b7.m(0.5):B.bD,1.5)
c1=A.i(10)
c2=A.a([],t)
if(b8){c3=A.i(9)
c4=B.l.aa(c7.cx*4,0.25,1)
c2.push(A.iL(c3,A.mi(A.wr(x,B.jV,c8,c8),c4),B.bO))}else c2.push(D.asp)
c2.push(A.eb(4,A.w(c8,D.YD,B.n,c8,c8,new A.x(b7,c8,c8,c8,c8,c8,B.ap),c8,c8,c8,c8,B.hy,c8,c8,c8),c8,c8,c8,4,c8,c8))
b4=A.l8(A.bm(!1,b6,!0,A.w(c8,new A.d_(B.a4,c8,B.bm,B.z,c2,c8),B.n,c8,c8,new A.x(B.fQ,c8,c0,c1,c8,c8,B.u),c8,80,c8,c8,c8,c8,c8,80),c8,!0,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,b4,c8,c8,c8,c8,c8,c8,c8),c8,c8,"Click to upload or select watermark logo",c8,c8,c8,c8,c8,c8)
b6=c7.k1
c0=b6?c8:c7.gawA()
b6=b6?B.jO:B.wm
c1=c7.ch
if(c1!=null&&c1.length!==0)c1="Change Watermark Logo"
else c1=d5.length!==0?"Upload Custom Logo":"Upload Watermark Logo"
c0=A.a([A.cj(b6,A.c(c1,c8,c8,c8,c8,c8,c8,c8,c8),c0,c8)],t)
if(b8){b6=A.a([],t)
if(B.d.aN(x,"data:"))b6.push(A.ep(E.Ki,D.ajC,c7.k1?c8:new C.cpM(c7,x,d6),c8))
b8=c7.ch
if(b8!=null&&b8.length!==0)b6.push(A.ep(D.aSA,D.cA9,new C.cpN(c7),c8))
B.h.B(c0,A.a([B.aJ,A.ca(B.a2,b6,B.b6,B.a2,4,8)],t))}c0.push(B.aL)
b6=c7.ch
b8=b6!=null
if(b8&&b6.length!==0)c1="Custom watermark logo active"
else c1=d5.length!==0?"Using Main Library Logo as watermark":"No logo set yet. Tap to upload or sync with Library Logo."
if(b8&&b6.length!==0)b6=A.G(d6).ax.a===B.ax?B.fR:B.cc
else if(d5.length!==0)b6=A.G(d6).ax.a===B.ax?B.p5:B.k1
else b6=A.G(d6).ax.a===B.ax?B.ns:B.hq
c0.push(A.c(c1,c8,c8,c8,c8,A.A(c8,c8,b6,c8,c8,c8,c8,c8,c8,c8,c8,11,c8,c8,B.aT,c8,c8,!0,c8,c8,c8,c8,c8,c8,c8,c8),c8,c8,c8))
c0=A.u(A.a([b4,B.dr,A.J(A.z(c0,B.x,c8,B.f,B.i,0,B.o),1,c8)],t),B.x,B.f,B.i,0,c8,c8)
b4=g?b7:h
b6=A.i(6)
b8=B.l.L(c7.cx*100)
b4=A.u(A.a([D.czU,B.c7,A.w(c8,A.c(""+b8+"%",c8,c8,c8,c8,A.A(c8,c8,a0?l.c:d,c8,c8,c8,c8,c8,c8,c8,c8,12,c8,c8,B.w,c8,c8,!0,c8,c8,c8,c8,c8,c8,c8,c8),c8,c8,c8),B.n,c8,c8,new A.x(b4,c8,c8,b6,c8,c8,B.u),c8,c8,c8,c8,B.fV,c8,c8,c8)],t),B.k,B.f,B.i,0,c8,c8)
b6=B.l.aa(c7.cx,0.02,0.3)
b6=C.bBE(28,""+B.l.L(c7.cx*100)+"%",0.3,0.02,new C.cpO(c7),b6)
b8=g?b7:h
c1=A.i(6)
c2=B.l.L(c7.cy*100)
b8=A.u(A.a([D.cM0,B.c7,A.w(c8,A.c(""+c2+"%",c8,c8,c8,c8,A.A(c8,c8,a0?l.c:d,c8,c8,c8,c8,c8,c8,c8,c8,12,c8,c8,B.w,c8,c8,!0,c8,c8,c8,c8,c8,c8,c8,c8),c8,c8,c8),B.n,c8,c8,new A.x(b8,c8,c8,c1,c8,c8,B.u),c8,c8,c8,c8,B.fV,c8,c8,c8)],t),B.k,B.f,B.i,0,c8,c8)
c1=B.l.aa(c7.cy,0.4,1)
B.h.B(b3,A.a([B.a9,c0,B.a9,b4,b6,D.c1N,b8,C.bBE(12,""+B.l.L(c7.cy*100)+"%",1,0.4,new C.cpP(c7),c1)],t))}d4=A.bO(new A.T(B.e4,A.z(b3,B.x,c8,B.f,B.i,0,B.o),c8),c8,c8,0,c8,c8,new A.at(w,new A.aI(d4,1,B.S,-1)))
w=A.i(16)
if(j){k=l.C
if(k==null)k=l.k3}k=k.m(0.6)
j=g?b7:h
h=A.i(10)
j=A.w(c8,A.Y(D.aHw,a0?l.c:d,c8,c8,20),B.n,c8,c8,new A.x(j,c8,c8,h,c8,c8,B.u),c8,c8,c8,c8,B.aK,c8,c8,c8)
h=A.c("Receipt Details & Policies",c8,c8,c8,c8,a2?c8:a1.b_(B.w),c8,c8,c8)
if(a8)g=c8
else{g=l.ry
if(g==null){g=l.C
if(g==null)g=l.k3}g=a5.bb(g)}g=A.u(A.a([j,B.a3,A.J(A.z(A.a([h,A.c("Display toggles, student code of conduct and footer",c8,B.Z,c8,c8,g,c8,c8,c8)],t),B.x,c8,B.f,B.i,0,B.o),1,c8)],t),B.k,B.f,B.i,0,c8,c8)
h=v.h(0,c9)
j=A.f7(B.a8,!0,new C.cpQ(c7),c8,D.cBD,D.cyq,h!==!1)
h=v.h(0,"Terms")
h=A.f7(B.a8,!0,new C.cpR(c7),c8,D.cCM,D.cvq,h!==!1)
d=v.h(0,d0)
d=A.f7(B.a8,!0,new C.cpS(c7),c8,D.cG2,D.cMT,d!==!1)
a0=v.h(0,"Logo")
a0=A.f7(B.a8,!0,new C.cpT(c7),c8,D.cui,D.cyg,a0!==!1)
v=v.h(0,"Contact")
v=A.f7(B.a8,!0,new C.cpU(c7),c8,D.cNJ,D.ctt,v!==!1)
a1=A.c("Custom Terms & Policies (Optional)",c8,c8,c8,c8,b9?c8:e.b_(B.w),c8,c8,c8)
a2=A.bU(c8,B.ak,!1,c8,!0,B.z,c8,A.bW(),c7.y,c8,c8,c8,c8,c8,2,D.aXd,B.J,!0,c8,!0,c8,!1,c8,B.aB,c8,c8,c8,c8,c8,c8,c8,c8,4,c8,c8,!1,"\u2022",c8,new C.cpW(c7),c8,c8,c8,!1,c8,c8,!1,c8,!0,c8,B.ag,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,c8,!0,B.Q,c8,B.R,c8,c8,c8,c8)
w=A.bO(new A.T(B.e4,A.z(A.a([g,B.a9,j,h,d,a0,v,B.es,a1,B.aJ,D.cL0,B.N,a2,B.P,A.c("Receipt Footer Note",c8,c8,c8,c8,b9?c8:e.b_(B.w),c8,c8,c8),B.N,A.bT(c8,!1,c8,a6,D.aYw,c8,!1,c8,c8,c8,c8,c8,c8,2,c8,!1,new C.cpX(c7),c8,c8,c8,!1,c8,c8,B.Q,c8,B.R,c8,c8)],t),B.x,c8,B.f,B.i,0,B.o),c8),c8,c8,0,c8,c8,new A.at(w,new A.aI(k,1,B.S,-1)))
v=(f?l.k2:a3).m(0.35)
l=A.i(12)
b7=A.Y(B.dp,b7,c8,c8,20)
d2=A.aE(new A.d1(B.no,A.fo(A.a([d2,B.P,i,B.P,d4,B.P,w,B.P,A.bO(new A.T(B.aw,A.z(A.a([A.u(A.a([b7,B.D,A.c("Where Branding Elements Are Used",c8,c8,c8,c8,b9?c8:e.b_(B.w),c8,c8,c8)],t),B.k,B.f,B.i,0,c8,c8),B.af,c7.Vz("Official Logo","Browser tab favicon, fee receipt top header, student ID card front, and student portal navigation."),c7.Vz("Official Stamp","Fee receipts (Authorized Signatory seal) and student ID card back (Authorized Stamp / Seal verification box)."),c7.Vz("Watermark","Faintly behind fee receipts and student ID card backgrounds (anti-forgery authenticity)."),c7.Vz("Org Name & Contact","Receipts, ID cards, emergency cards, WhatsApp confirmation receipts, and public seat occupancy page.")],t),B.x,c8,B.f,B.i,0,B.o),c8),c8,v,c8,c8,c8,new A.at(l,B.E)),D.cf6],t),c8,B.aw,c8,c8,!1),c8),c8,c8)
d4=A.G(d6)
b5=A.a([new A.b0(0,B.aa,B.a0.m(0.08),B.xc,8)],b5)
w=c7.go?c8:c7.gayh()
v=A.b4(c8,c8,c8,B.je,c8,new A.at(A.i(12),B.E),c8,c8,c8)
t=c7.go
l=t?B.iC:B.tb
return A.cf(u,c8,d2,A.ex(!0,A.w(c8,A.bt(l,A.c(t?"Saving Template...":"Save Template Settings",c8,c8,c8,c8,B.dJ,c8,c8,c8),w,v),B.n,c8,c8,new A.x(d4.at,c8,c8,c8,b5,c8,B.u),c8,c8,c8,c8,B.lt,c8,c8,c8),!0,!1,B.a8,!0,!0),!1,c8,c8)},
Yw(d,e,f,g,h){var x=null,w=e==null?this.fr:e,v=A.A(x,x,d,x,x,x,x,x,x,x,x,f,g,x,h,x,x,!0,x,x,x,x,x,x,x,x)
switch(w){case"noto_serif":return C.e1v().$1$textStyle(v)
case"poppins":return A.Ds().$1$textStyle(v)
case"roboto_mono":return C.e1w().$1$textStyle(v)
default:return C.e1u().$1$textStyle(v)}},
mX(d,e,f){return this.Yw(d,null,e,null,f)},
boB(d,e,f){return this.Yw(d,null,e,f,null)},
HX(d,e){return this.Yw(d,null,e,null,null)},
boC(d,e,f){return this.Yw(null,d,e,null,f)},
awR(d,e,f){var x=null,w=A.eM(d,x,x)
if(w==null)return A.bk(x,f,f)
return A.nm(B.a4,x,x,new C.cpc(f),B.dE,e,x,f,w,x,x,!1,B.dF,f)},
awQ(d,e){return this.awR(d,B.jV,e)},
Vz(d,e){var x,w=null,v=this.c
v.toString
v=A.w(w,w,B.n,w,w,new A.x(A.G(v).ax.b,w,w,w,w,w,B.ap),w,6,w,D.aAW,w,w,w,6)
x=this.c
x.toString
x=A.G(x)
return new A.T(B.iT,A.u(A.a([v,A.J(A.axU(w,w,w,B.fH,w,w,!0,w,A.fP(A.a([A.fP(w,w,w,w,w,w,w,w,w,B.bJ,d+": "),A.fP(w,w,w,w,w,w,w,w,w,w,e)],y.R),w,w,w,w,w,w,w,w,x.ok.Q,w),B.Q,w,w,B.c3,B.cP),1,w)],y.p),B.x,B.f,B.i,0,w,w),w)}}
var z=a.updateTypes(["~()","al(al)","au<~>()","~(al)","R({background:tp?,backgroundColor:S?,color:S?,decoration:xc?,decorationColor:S?,decorationStyle:Ib?,decorationThickness:al?,fontFeatures:Q<B2>?,fontSize:al?,fontStyle:FE?,fontWeight:mF?,foreground:tp?,height:al?,letterSpacing:al?,locale:qL?,shadows:Q<ob>?,textBaseline:v7?,textStyle:R?,wordSpacing:al?})","~(a7)","zw(mY)","~(xn)","~(pC)","~(Eu)","~(mB)","~(I7)","~(zu)","F(W?)"])
C.bEt.prototype={
$1(d){var x=this.a
return this.b.$1(C.bEq(x.b,x.a.gMc()))},
$S(){return this.c.i("0/(mY)")}}
C.bEu.prototype={
$1(d){var x=this.a
return C.bEq(x.b,x.a.gMc())},
$S:z+6}
C.bgX.prototype={
$0(){var $async$$0=A.j(function(b0,b1){switch(b0){case 2:s=v
x=s.pop()
break
case 1:t.push(b1)
x=u}for(;;)switch(x){case 0:a4=r.a
a5=null
a8=A
a9="plugins.flutter.io/firebase_storage/taskEvent/"
x=3
return A.cE(a4.f,$async$$0,w)
case 3:a6=new a8.wh(a9+b1,B.el).a3s()
u=5
g=new A.lA(A.i6(a6,"stream",y.K),y.o)
u=8
f=y.N,e=y.z,d=a4.w
case 11:x=13
return A.cE(g.E(),$async$$0,w)
case 13:if(!b1){x=12
break}q=g.gY()
p=D.bTp[J.k(q,"taskState")]
if(p===B.O6){a4.c=!0
o=A.d7(J.k(q,"error"),f,e)
n=J.k(o,"code")
if(!J.p(n,"canceled")){a0=a4.x
a0===$&&A.b()
a0=a0.a===B.xM}else a0=!1
if(a0)n="canceled"
a0=n
a1=J.k(o,"message")
m=new A.nW("firebase_storage",a1,a0==null?"unknown":a0,null)
if(!J.p(n,"canceled")){a0=a4.x
a0===$&&A.b()
a0=A.N(["path",r.b,"bytesTransferred",a0.b.h(0,"bytesTransferred"),"totalBytes",a4.x.b.h(0,"totalBytes"),"metadata",a5],f,e)
a1=$.a_P()
a0=new C.ME(d,a0,p,a0)
a2=$.e8()
a2.a.set(a0,a1)
a4.x=a0}a4.b=m
f=a4.d
if(f!=null){if((f.a.a&30)!==0)A.aq(A.aZ("Future already completed"))
f.i8(A.os(m,null))}x=12
break}if(p===B.xM){a4.c=!0
a0=A.d7(J.k(q,"snapshot"),f,e)
a1=$.a_P()
j=new C.ME(d,a0,p,a0)
a0=$.e8()
a0.a.set(j,a1)
l=j
a4.x=l
x=12
break}if(p===B.Ed||p===B.Ec||p===B.O5){a0=a4.x
a0===$&&A.b()
a0=a0.a!==B.xM}else a0=!1
x=a0?14:15
break
case 14:k=A.d7(J.k(q,"snapshot"),f,e)
a5=J.k(k,"metadata")
a0=k
a1=$.a_P()
a3=new C.ME(d,a0,p,a0)
a0=$.e8()
a0.a.set(a3,a1)
j=a3
a4.x=j
x=16
v=[1,9]
return A.cE(A.jq(j),$async$$0,w)
case 16:case 15:if(p===B.Ed){a4.c=!0
f=a4.d
if(f!=null){e=a4.x
e===$&&A.b()
a4=f.a
if((a4.a&30)!==0)A.aq(A.aZ("Future already completed"))
a4.mK(e)}x=12
break}x=11
break
case 12:s.push(10)
x=9
break
case 8:s=[5]
case 9:u=5
x=17
return A.cE(g.aO(),$async$$0,w)
case 17:x=s.pop()
break
case 10:u=2
x=7
break
case 5:u=4
a7=t.pop()
i=A.aa(a7)
h=A.ba(a7)
C.due(i,h)
x=7
break
case 4:x=2
break
case 7:case 1:return A.cE(null,0,w)
case 2:return A.cE(t.at(-1),1,w)}})
var x=0,w=A.u_($async$$0,y.i),v,u=2,t=[],s=[],r=this,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9
return A.u1(w)},
$S:1822}
C.bgV.prototype={
$1(d){return d.hb()},
$S:516}
C.bgW.prototype={
$1(d){return d.aO()},
$S:516}
C.bgY.prototype={
$1(d){var x=this.a.x
x===$&&A.b()
return A.dR(x,y.i)},
$S:1824}
C.d_A.prototype={
$1(d){return C.kP(d.b,J.k(this.a,d.a))},
$S:193}
C.cHu.prototype={
$0(){this.a.Q=!0},
$S:0}
C.cHt.prototype={
$0(){this.a.Q=!1},
$S:0}
C.cHv.prototype={
$0(){this.a.ay=this.b},
$S:0}
C.cHw.prototype={
$0(){this.a.ch=this.b},
$S:0}
C.cHr.prototype={
$0(){var x,w,v,u=this
u.b.a.toString
x=u.c
w=y._
v=A.dK(u.a.a.ax,x,w)
return v==null?A.dK(u.d.gdC(),x,w):v},
$S:428}
C.cHs.prototype={
$0(){return A.aN(this.a,B.qH,y.w).w.a},
$S:443}
C.cHp.prototype={
$0(){var x,w=this.a
if(!w.gdP().gdl()){x=w.gdP()
x=x.b&&B.h.f5(x.ghM(),A.m6())}else x=!1
if(x)w.gdP().ic()},
$S:0}
C.cHq.prototype={
$1(d){var x=this.a.a.go
x.toString
return this.b.b2v(x)},
$S:24}
C.cuD.prototype={
$1(d){return d.a},
$S:203}
C.cuC.prototype={
$1(d){return d.b},
$S:203}
C.cuE.prototype={
$0(){var x=this.a,w=x.C
w.w=null
if(!x.b9){x=w.e
x===$&&A.b()
x=x.gbU()===B.cs}else x=!1
if(x){x=w.e
x===$&&A.b()
x.dZ()}},
$S:0}
C.cuF.prototype={
$2(d,e){var x,w,v,u,t,s,r,q,p,o,n=this.a
if(n.y!=null&&n.aw.e!=null){x=n.b6
w=x.dx
if(w!=null){v=e.ap(0,this.b)
u=x.go===D.DY
if(u)t=B.Q4
else{t=n.am
t===$&&A.b()}if(u)u=B.Q4
else{u=n.aD
u===$&&A.b()}s=n.Z
r=n.fq
q=n.ck
p=n.bk
o=n.fp
if(o.gab(0))o=n.gW()
w.a3_(d,v,t,u,s>0,n.aw,n,o,x,r,p,q)}}},
$S:42}
C.cHo.prototype={
$1(d){if(d.k(0,B.oz))return this.a.gh3().b.bG(0.1)
if(d.k(0,B.aZ))return this.a.gh3().b.bG(0.08)
if(d.k(0,B.b_))return this.a.gh3().b.bG(0.1)
return B.ad},
$S:12}
C.coT.prototype={
$0(){return this.a.fy=!1},
$S:0}
C.coU.prototype={
$0(){return this.a.fy=!1},
$S:0}
C.coS.prototype={
$0(){var x,w,v,u,t,s,r,q=null,p=this.a,o=this.b,n=A.D(o.h(0,"prefix"))
if(n==null)n="REC"
p.x.sai(n)
n=A.D(o.h(0,"customTerms"))
if(n==null)n=""
p.y.sai(n)
n=A.D(o.h(0,"footerText"))
if(n==null)n="Thank you for your payment! \ud83d\udcda"
p.z.sai(n)
p.as=A.D(o.h(0,"stampUrl"))
n=A.b6(o.h(0,"stampEnabled"))
if(n==null){n=p.as
n=n!=null&&n.length!==0}p.at=n
n=A.bf(o.h(0,"stampRotation"))
if(n==null)n=q
p.ax=n==null?-12:n
n=A.bf(o.h(0,"stampScale"))
if(n==null)n=q
p.ay=n==null?1:n
p.ch=A.D(o.h(0,"watermarkUrl"))
n=A.b6(o.h(0,"watermarkEnabled"))
p.CW=n!==!1
n=A.bf(o.h(0,"watermarkOpacity"))
if(n==null)n=q
p.cx=B.l.aa(n==null?0.08:n,0.02,0.4)
n=A.bf(o.h(0,"watermarkScale"))
if(n==null)n=q
p.cy=B.l.aa(n==null?0.88:n,0.1,0.98)
n=A.bf(o.h(0,"headerFontSize"))
if(n==null)n=q
p.db=n==null?22:n
v=A.D(o.h(0,"receiptStyle"))
if(v==null)v="classic"
p.dx=v==="compact"?"classic":v
u=A.D(o.h(0,"pageSize"))
if(u==null)u="a4"
p.dy=u.toLowerCase()==="a5"?"a4":u
p.fr=A.dbD(A.D(o.h(0,"fontFamily")))
x=A.D(o.h(0,"primaryColor"))
if(x!=null&&x.length!==0)try{w=A.cH("FF"+x,q,16)
p.fx=A.bl(B.l.a1(w,24)&255,B.l.a1(w,16)&255,B.l.a1(w,8)&255,w&255)}catch(t){}for(n=p.w,s=new A.dU(n,n.r,n.e,A.C(n).i("dU<1>"));s.E();){r=s.d
if(o.ar(r))n.j(0,r,A.ir(o.h(0,r)))}p.Q=!1},
$S:0}
C.coZ.prototype={
$1(d){var x=null,w=A.a([A.bZ(!1,x,x,x,!0,x,x,x,!0,x,x,D.aK7,x,x,x,x,new C.coW(d),!1,x,x,x,x,x,x,x,x,D.cEb,x,x,x),A.bZ(!1,x,x,x,!0,x,x,x,!0,x,x,D.aUa,x,x,x,x,new C.coX(d),!1,x,x,x,x,x,x,x,x,B.Et,x,x,x)],y.p),v=this.a,u=v.as
if(u!=null&&u.length!==0)w.push(A.bZ(!1,x,x,x,!0,x,x,x,!0,x,x,B.X3,x,x,x,x,new C.coY(v,d),!1,x,x,x,x,x,x,x,x,D.cLJ,x,x,x))
return A.ex(!0,A.ca(B.a2,w,B.b6,B.a2,0,0),!0,!1,B.a8,!0,!0)},
$S:34}
C.coW.prototype={
$0(){A.a8(this.a,!1).R(B.iw)
return null},
$S:0}
C.coX.prototype={
$0(){A.a8(this.a,!1).R(B.j5)
return null},
$S:0}
C.coY.prototype={
$0(){A.a8(this.b,!1).R(null)
var x=this.a
x.u(new C.coV(x))},
$S:0}
C.coV.prototype={
$0(){return this.a.as=null},
$S:0}
C.cp_.prototype={
$0(){return this.a.id=!0},
$S:0}
C.cp0.prototype={
$0(){var x=this.a
x.as=this.b
x.at=!0},
$S:0}
C.cp1.prototype={
$0(){return this.a.id=!1},
$S:0}
C.cp7.prototype={
$1(d){var x,w=null,v=A.a([A.bZ(!1,w,w,w,!0,w,w,w,!0,w,w,B.AV,w,w,w,w,new C.cp3(d),!1,w,w,w,w,w,w,w,w,B.Ou,w,w,w),A.bZ(!1,w,w,w,!0,w,w,w,!0,w,w,B.wr,w,w,w,w,new C.cp4(d),!1,w,w,w,w,w,w,w,w,D.csD,w,w,w)],y.p),u=this.b
if(u!=null&&u.length!==0)v.push(A.bZ(!1,w,w,w,!0,w,w,w,!0,w,w,D.aLs,w,w,w,w,new C.cp5(d),!1,w,w,w,w,w,D.cGH,w,w,D.cuI,w,w,w))
u=this.a
x=u.ch
if(x!=null&&x.length!==0)v.push(A.bZ(!1,w,w,w,!0,w,w,w,!0,w,w,B.nV,w,w,w,w,new C.cp6(u,d),!1,w,w,w,w,w,w,w,w,D.cwT,w,w,w))
return A.ex(!0,A.ca(B.a2,v,B.b6,B.a2,0,0),!0,!1,B.a8,!0,!0)},
$S:34}
C.cp3.prototype={
$0(){A.a8(this.a,!1).R("gallery")
return null},
$S:0}
C.cp4.prototype={
$0(){A.a8(this.a,!1).R("camera")
return null},
$S:0}
C.cp5.prototype={
$0(){A.a8(this.a,!1).R("use_library_logo")
return null},
$S:0}
C.cp6.prototype={
$0(){A.a8(this.b,!1).R(null)
var x=this.a
x.u(new C.cp2(x))},
$S:0}
C.cp2.prototype={
$0(){return this.a.ch=null},
$S:0}
C.cp8.prototype={
$0(){var x=this.b
x.ch=this.a.a
x.CW=!0},
$S:0}
C.cp9.prototype={
$0(){return this.a.k1=!0},
$S:0}
C.cpa.prototype={
$0(){var x=this.a
x.ch=this.b
x.CW=!0},
$S:0}
C.cpb.prototype={
$0(){return this.a.k1=!1},
$S:0}
C.cpe.prototype={
$0(){return this.a.go=!0},
$S:0}
C.cpf.prototype={
$0(){return this.a.go=!1},
$S:0}
C.cpd.prototype={
$1(d){return this.aMS(d)},
aMS(d){var x=0,w=A.o(y.G),v,u=this
var $async$$1=A.j(function(e,f){if(e===1)return A.l(f,w)
for(;;)switch(x){case 0:v=u.a
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$$1,w)},
$S:239}
C.cpI.prototype={
$2(d,e){var x=e.gA(),w=this.a
if(!w.fy&&!w.go&&!w.Q&&x!=null)w.anG(x)},
$S:1825}
C.cpJ.prototype={
$1(d){var x=this.a
return x.u(new C.cpA(x))},
$S:8}
C.cpA.prototype={
$0(){return this.a.Q=!0},
$S:0}
C.cpK.prototype={
$1(d){var x=null,w=this.a,v=A.a5(w.fx.p(0,d)?B.B:B.ad,3),u=w.fx.p(0,d)?A.a([new A.b0(1,B.aa,d.m(0.5),B.W,8)],y.V):x,t=w.fx.p(0,d)?D.aOH:x
return A.f9(x,A.kr(t,x,B.bd,new A.x(d,x,v,x,u,x,B.ap),B.iS,x,36,D.aAH,x,36),B.J,!1,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,new C.cpz(w,d),x,x,x,x,x,x,!1,B.c6)},
$S:1826}
C.cpz.prototype={
$0(){var x=this.a
return x.u(new C.cph(x,this.b))},
$S:0}
C.cph.prototype={
$0(){var x=this.a
x.fx=this.b
x.Q=!0},
$S:0}
C.cpV.prototype={
$0(){var x=0,w=A.o(y.H),v=this,u,t
var $async$$0=A.j(function(d,e){if(d===1)return A.l(e,w)
for(;;)switch(x){case 0:u=v.a
x=2
return A.d(A.aW8(v.b,u.fx,"Pick Custom Receipt Accent Color"),$async$$0)
case 2:t=e
if(t!=null&&u.c!=null)u.u(new C.cpy(u,t))
return A.m(null,w)}})
return A.n($async$$0,w)},
$S:1}
C.cpy.prototype={
$0(){var x=this.a
x.fx=this.b
x.Q=!0},
$S:0}
C.cpY.prototype={
$1(d){var x=null,w=this.a,v=d.a,u=w.fr===v
return A.h1(x,x,A.c(d.b,x,x,x,x,w.boC(v,12,u?B.w:B.aT),x,x,x),x,x,new C.cpx(w,d),x,u,x,x,x)},
$S:1827}
C.cpx.prototype={
$1(d){var x=this.a
x.u(new C.cpg(x,this.b))},
$S:2}
C.cpg.prototype={
$0(){var x=this.a
x.fr=this.b.a
x.Q=!0},
$S:0}
C.cpZ.prototype={
$1(d){var x=this.a
return x.u(new C.cpw(x,d))},
$S:2}
C.cpw.prototype={
$0(){return this.a.at=this.b},
$S:0}
C.cq_.prototype={
$0(){var x=0,w=A.o(y.H),v=[],u=this,t,s,r,q,p
var $async$$0=A.j(function(d,e){if(d===1)return A.l(e,w)
for(;;)switch(x){case 0:p=u.a
p.u(new C.cps(p))
try{r=p.as
r.toString
t=A.daM(r,225)
p.u(new C.cpt(p,t))
if(p.c!=null)u.b.M(y.q).f.a2(D.cfE)}catch(o){s=A.aa(o)
if(p.c!=null)u.b.M(y.q).f.a2(A.aV(null,null,null,null,null,B.z,null,A.c("Could not remove background: "+A.q(s),null,null,null,null,null,null,null,null),null,B.L,null,null,null,null,null,null,null,null,null,null))}finally{if(p.c!=null)p.u(new C.cpu(p))}return A.m(null,w)}})
return A.n($async$$0,w)},
$S:1}
C.cps.prototype={
$0(){return this.a.id=!0},
$S:0}
C.cpt.prototype={
$0(){return this.a.as=this.b},
$S:0}
C.cpu.prototype={
$0(){return this.a.id=!1},
$S:0}
C.cq0.prototype={
$0(){var x=this.a
return x.u(new C.cpr(x))},
$S:0}
C.cpr.prototype={
$0(){return this.a.as=null},
$S:0}
C.cq1.prototype={
$1(d){var x=this.a
return x.u(new C.cpq(x,d))},
$S:91}
C.cpq.prototype={
$0(){return this.a.ax=A.xB(B.l.S(this.b,1))},
$S:0}
C.cq2.prototype={
$1(d){var x=this.a
return x.u(new C.cpp(x,this.b))},
$S:2}
C.cpp.prototype={
$0(){return this.a.ax=this.b.a},
$S:0}
C.cq3.prototype={
$1(d){var x=this.a
return x.u(new C.cpo(x,d))},
$S:91}
C.cpo.prototype={
$0(){return this.a.ay=A.xB(B.l.S(this.b,2))},
$S:0}
C.cpL.prototype={
$1(d){var x=this.a
return x.u(new C.cpn(x,d))},
$S:2}
C.cpn.prototype={
$0(){return this.a.CW=this.b},
$S:0}
C.cpM.prototype={
$0(){var x=0,w=A.o(y.H),v=[],u=this,t,s,r,q
var $async$$0=A.j(function(d,e){if(d===1)return A.l(e,w)
for(;;)switch(x){case 0:q=u.a
q.u(new C.cpH(q))
try{t=A.daM(u.b,225)
q.u(new C.cpl(q,t))
if(q.c!=null)u.c.M(y.q).f.a2(D.chq)}catch(p){s=A.aa(p)
if(q.c!=null)u.c.M(y.q).f.a2(A.aV(null,null,null,null,null,B.z,null,A.c("Could not remove background: "+A.q(s),null,null,null,null,null,null,null,null),null,B.L,null,null,null,null,null,null,null,null,null,null))}finally{if(q.c!=null)q.u(new C.cpm(q))}return A.m(null,w)}})
return A.n($async$$0,w)},
$S:1}
C.cpH.prototype={
$0(){return this.a.k1=!0},
$S:0}
C.cpl.prototype={
$0(){return this.a.ch=this.b},
$S:0}
C.cpm.prototype={
$0(){return this.a.k1=!1},
$S:0}
C.cpN.prototype={
$0(){var x=this.a
return x.u(new C.cpG(x))},
$S:0}
C.cpG.prototype={
$0(){return this.a.ch=null},
$S:0}
C.cpO.prototype={
$1(d){var x=this.a
return x.u(new C.cpF(x,d))},
$S:91}
C.cpF.prototype={
$0(){return this.a.cx=A.xB(B.l.S(this.b,2))},
$S:0}
C.cpP.prototype={
$1(d){var x=this.a
return x.u(new C.cpE(x,d))},
$S:91}
C.cpE.prototype={
$0(){return this.a.cy=A.xB(B.l.S(this.b,2))},
$S:0}
C.cpQ.prototype={
$1(d){var x=this.a
return x.u(new C.cpD(x,d))},
$S:2}
C.cpD.prototype={
$0(){var x=this.b
this.a.w.j(0,"Seat Number",x)
return x},
$S:0}
C.cpR.prototype={
$1(d){var x=this.a
return x.u(new C.cpC(x,d))},
$S:2}
C.cpC.prototype={
$0(){var x=this.b
this.a.w.j(0,"Terms",x)
return x},
$S:0}
C.cpS.prototype={
$1(d){var x=this.a
return x.u(new C.cpB(x,d))},
$S:2}
C.cpB.prototype={
$0(){var x=this.b
this.a.w.j(0,"Signature",x)
return x},
$S:0}
C.cpT.prototype={
$1(d){var x=this.a
return x.u(new C.cpv(x,d))},
$S:2}
C.cpv.prototype={
$0(){var x=this.b
this.a.w.j(0,"Logo",x)
return x},
$S:0}
C.cpU.prototype={
$1(d){var x=this.a
return x.u(new C.cpk(x,d))},
$S:2}
C.cpk.prototype={
$0(){var x=this.b
this.a.w.j(0,"Contact",x)
return x},
$S:0}
C.cpW.prototype={
$1(d){var x=this.a
return x.u(new C.cpj(x))},
$S:8}
C.cpj.prototype={
$0(){return this.a.Q=!0},
$S:0}
C.cpX.prototype={
$1(d){var x=this.a
return x.u(new C.cpi(x))},
$S:8}
C.cpi.prototype={
$0(){return this.a.Q=!0},
$S:0}
C.cpc.prototype={
$3(d,e,f){var x=this.a
return A.bk(null,x,x)},
$S:1828};(function aliases(){var x=C.aln.prototype
x.aXt=x.by
x.aXu=x.bl
x=C.alp.prototype
x.aXx=x.by
x.aXy=x.bl
x=C.alx.prototype
x.aXJ=x.t})();(function installTearOffs(){var x=a._static_1,w=a._instance_1u,v=a._instance_0u,u=a.installStaticTearOff
x(C,"e18","Di",13)
var t
w(t=C.aiS.prototype,"gbco","bcp",3)
w(t,"gacc","acd",3)
w(t,"gaca","acb",3)
w(t,"gaZF","aZG",7)
w(t,"gbdf","bdg",5)
w(t,"gbdK","bdL",5)
v(t=C.Zy.prototype,"gb8D","a8s",0)
w(t,"gacc","acd",8)
w(t,"gbvf","bvg",9)
w(t,"gaca","acb",10)
w(t,"gbgu","bgv",11)
w(t,"gbgB","bgC",12)
w(t,"gd2","cD",1)
w(t,"gcz","cB",1)
w(t,"gd4","cC",1)
w(t,"gd1","cA",1)
v(t,"gbOF","bOG",0)
v(t,"gbLI","aHD",0)
v(t,"gbGB","aFf",0)
v(t=C.ahh.prototype,"gawz","Da",2)
v(t,"gawA","Db",2)
v(t,"gayh","Ie",2)
v(t,"gboD","OF",2)
u(C,"e1u",0,null,["$19$background$backgroundColor$color$decoration$decorationColor$decorationStyle$decorationThickness$fontFeatures$fontSize$fontStyle$fontWeight$foreground$height$letterSpacing$locale$shadows$textBaseline$textStyle$wordSpacing","$0","$3$fontSize$fontWeight$letterSpacing","$18$background$backgroundColor$color$decoration$decorationColor$decorationStyle$decorationThickness$fontFeatures$fontSize$fontStyle$fontWeight$foreground$height$letterSpacing$locale$shadows$textBaseline$wordSpacing","$2$fontWeight$letterSpacing","$1$color","$1$fontWeight","$2$fontSize$fontWeight","$3$color$fontSize$height","$4$fontSize$fontWeight$height$letterSpacing","$4$color$fontSize$height$letterSpacing","$2$color$height","$2$color$fontSize","$2$color$fontWeight","$1$height","$2$color$fontSize","$3$color$fontWeight$letterSpacing","$2$color$fontWeight","$1$fontSize","$2$fontSize$fontWeight","$3$fontSize$fontWeight$height","$3$color$fontWeight$letterSpacing","$3$color$fontWeight$letterSpacing","$3$color$fontSize$fontWeight","$3$color$fontWeight$letterSpacing","$3$color$fontSize$fontStyle","$3$color$fontSize$fontWeight","$3$color$fontSize$fontWeight","$1$textStyle","$3$color$fontSize$fontWeight","$3$color$fontSize$height","$3$color$decoration$fontWeight","$3$color$fontSize$height","$2$color$letterSpacing","$3$color$fontSize$height","$2$fontWeight$height","$3$color$fontSize$height","$1$fontFeatures"],["hM",function(){var s=null
return C.hM(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,s,s,s,s,s,s,d,s,e,s,s,f,s,s,s,s,s)},function(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){return C.hM(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,null,a1)},function(d,e){var s=null
return C.hM(s,s,s,s,s,s,s,s,s,s,d,s,s,e,s,s,s,s,s)},function(d){var s=null
return C.hM(s,s,d,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hM(s,s,s,s,s,s,s,s,s,s,d,s,s,s,s,s,s,s,s)},function(d,e){var s=null
return C.hM(s,s,s,s,s,s,s,s,d,s,e,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e,f,g){var s=null
return C.hM(s,s,s,s,s,s,s,s,d,s,e,s,f,g,s,s,s,s,s)},function(d,e,f,g){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,s,s,f,g,s,s,s,s,s)},function(d,e){var s=null
return C.hM(s,s,d,s,s,s,s,s,s,s,s,s,e,s,s,s,s,s,s)},function(d,e){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,s,s,s,s,s,s,s,s,s)},function(d,e){var s=null
return C.hM(s,s,d,s,s,s,s,s,s,s,e,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hM(s,s,s,s,s,s,s,s,s,s,s,s,d,s,s,s,s,s,s)},function(d,e){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,s,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e){var s=null
return C.hM(s,s,d,s,s,s,s,s,s,s,e,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hM(s,s,s,s,s,s,s,s,d,s,s,s,s,s,s,s,s,s,s)},function(d,e){var s=null
return C.hM(s,s,s,s,s,s,s,s,d,s,e,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,s,s,s,s,s,s,d,s,e,s,f,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,f,s,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hM(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,d,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,e,s,s,s,s,s,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e){var s=null
return C.hM(s,s,d,s,s,s,s,s,s,s,s,s,s,e,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e){var s=null
return C.hM(s,s,s,s,s,s,s,s,s,s,d,s,e,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hM(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d){var s=null
return C.hM(s,s,s,s,s,s,s,d,s,s,s,s,s,s,s,s,s,s,s)}],4,0)
u(C,"e1v",0,null,["$19$background$backgroundColor$color$decoration$decorationColor$decorationStyle$decorationThickness$fontFeatures$fontSize$fontStyle$fontWeight$foreground$height$letterSpacing$locale$shadows$textBaseline$textStyle$wordSpacing","$0","$3$fontSize$fontWeight$letterSpacing","$18$background$backgroundColor$color$decoration$decorationColor$decorationStyle$decorationThickness$fontFeatures$fontSize$fontStyle$fontWeight$foreground$height$letterSpacing$locale$shadows$textBaseline$wordSpacing","$2$fontWeight$letterSpacing","$1$color","$1$fontWeight","$2$fontSize$fontWeight","$3$color$fontSize$height","$4$fontSize$fontWeight$height$letterSpacing","$4$color$fontSize$height$letterSpacing","$2$color$height","$2$color$fontSize","$2$color$fontWeight","$1$height","$2$color$fontSize","$3$color$fontWeight$letterSpacing","$2$color$fontWeight","$1$fontSize","$2$fontSize$fontWeight","$3$fontSize$fontWeight$height","$3$color$fontWeight$letterSpacing","$3$color$fontWeight$letterSpacing","$3$color$fontSize$fontWeight","$3$color$fontWeight$letterSpacing","$3$color$fontSize$fontStyle","$3$color$fontSize$fontWeight","$3$color$fontSize$fontWeight","$1$textStyle","$3$color$fontSize$fontWeight","$3$color$fontSize$height","$3$color$decoration$fontWeight","$3$color$fontSize$height","$2$color$letterSpacing","$3$color$fontSize$height","$2$fontWeight$height","$3$color$fontSize$height","$1$fontFeatures"],["hN",function(){var s=null
return C.hN(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,s,s,s,s,s,s,d,s,e,s,s,f,s,s,s,s,s)},function(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){return C.hN(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,null,a1)},function(d,e){var s=null
return C.hN(s,s,s,s,s,s,s,s,s,s,d,s,s,e,s,s,s,s,s)},function(d){var s=null
return C.hN(s,s,d,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hN(s,s,s,s,s,s,s,s,s,s,d,s,s,s,s,s,s,s,s)},function(d,e){var s=null
return C.hN(s,s,s,s,s,s,s,s,d,s,e,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e,f,g){var s=null
return C.hN(s,s,s,s,s,s,s,s,d,s,e,s,f,g,s,s,s,s,s)},function(d,e,f,g){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,s,s,f,g,s,s,s,s,s)},function(d,e){var s=null
return C.hN(s,s,d,s,s,s,s,s,s,s,s,s,e,s,s,s,s,s,s)},function(d,e){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,s,s,s,s,s,s,s,s,s)},function(d,e){var s=null
return C.hN(s,s,d,s,s,s,s,s,s,s,e,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hN(s,s,s,s,s,s,s,s,s,s,s,s,d,s,s,s,s,s,s)},function(d,e){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,s,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e){var s=null
return C.hN(s,s,d,s,s,s,s,s,s,s,e,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hN(s,s,s,s,s,s,s,s,d,s,s,s,s,s,s,s,s,s,s)},function(d,e){var s=null
return C.hN(s,s,s,s,s,s,s,s,d,s,e,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,s,s,s,s,s,s,d,s,e,s,f,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,f,s,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hN(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,d,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,e,s,s,s,s,s,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e){var s=null
return C.hN(s,s,d,s,s,s,s,s,s,s,s,s,s,e,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e){var s=null
return C.hN(s,s,s,s,s,s,s,s,s,s,d,s,e,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hN(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d){var s=null
return C.hN(s,s,s,s,s,s,s,d,s,s,s,s,s,s,s,s,s,s,s)}],4,0)
u(C,"e1w",0,null,["$19$background$backgroundColor$color$decoration$decorationColor$decorationStyle$decorationThickness$fontFeatures$fontSize$fontStyle$fontWeight$foreground$height$letterSpacing$locale$shadows$textBaseline$textStyle$wordSpacing","$0","$3$fontSize$fontWeight$letterSpacing","$18$background$backgroundColor$color$decoration$decorationColor$decorationStyle$decorationThickness$fontFeatures$fontSize$fontStyle$fontWeight$foreground$height$letterSpacing$locale$shadows$textBaseline$wordSpacing","$2$fontWeight$letterSpacing","$1$color","$1$fontWeight","$2$fontSize$fontWeight","$3$color$fontSize$height","$4$fontSize$fontWeight$height$letterSpacing","$4$color$fontSize$height$letterSpacing","$2$color$height","$2$color$fontSize","$2$color$fontWeight","$1$height","$2$color$fontSize","$3$color$fontWeight$letterSpacing","$2$color$fontWeight","$1$fontSize","$2$fontSize$fontWeight","$3$fontSize$fontWeight$height","$3$color$fontWeight$letterSpacing","$3$color$fontWeight$letterSpacing","$3$color$fontSize$fontWeight","$3$color$fontWeight$letterSpacing","$3$color$fontSize$fontStyle","$3$color$fontSize$fontWeight","$3$color$fontSize$fontWeight","$1$textStyle","$3$color$fontSize$fontWeight","$3$color$fontSize$height","$3$color$decoration$fontWeight","$3$color$fontSize$height","$2$color$letterSpacing","$3$color$fontSize$height","$2$fontWeight$height","$3$color$fontSize$height","$1$fontFeatures"],["hS",function(){var s=null
return C.hS(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,s,s,s,s,s,s,d,s,e,s,s,f,s,s,s,s,s)},function(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,a1){return C.hS(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,a0,null,a1)},function(d,e){var s=null
return C.hS(s,s,s,s,s,s,s,s,s,s,d,s,s,e,s,s,s,s,s)},function(d){var s=null
return C.hS(s,s,d,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hS(s,s,s,s,s,s,s,s,s,s,d,s,s,s,s,s,s,s,s)},function(d,e){var s=null
return C.hS(s,s,s,s,s,s,s,s,d,s,e,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e,f,g){var s=null
return C.hS(s,s,s,s,s,s,s,s,d,s,e,s,f,g,s,s,s,s,s)},function(d,e,f,g){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,s,s,f,g,s,s,s,s,s)},function(d,e){var s=null
return C.hS(s,s,d,s,s,s,s,s,s,s,s,s,e,s,s,s,s,s,s)},function(d,e){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,s,s,s,s,s,s,s,s,s)},function(d,e){var s=null
return C.hS(s,s,d,s,s,s,s,s,s,s,e,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hS(s,s,s,s,s,s,s,s,s,s,s,s,d,s,s,s,s,s,s)},function(d,e){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,s,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e){var s=null
return C.hS(s,s,d,s,s,s,s,s,s,s,e,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hS(s,s,s,s,s,s,s,s,d,s,s,s,s,s,s,s,s,s,s)},function(d,e){var s=null
return C.hS(s,s,s,s,s,s,s,s,d,s,e,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,s,s,s,s,s,s,d,s,e,s,f,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,s,s,e,s,s,f,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,f,s,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d){var s=null
return C.hS(s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,s,d,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,e,s,s,s,s,s,s,f,s,s,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e){var s=null
return C.hS(s,s,d,s,s,s,s,s,s,s,s,s,s,e,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d,e){var s=null
return C.hS(s,s,s,s,s,s,s,s,s,s,d,s,e,s,s,s,s,s,s)},function(d,e,f){var s=null
return C.hS(s,s,d,s,s,s,s,s,e,s,s,s,f,s,s,s,s,s,s)},function(d){var s=null
return C.hS(s,s,s,s,s,s,s,d,s,s,s,s,s,s,s,s,s,s,s)}],4,0)})();(function inheritance(){var x=a.mixinHard,w=a.mixin,v=a.inherit,u=a.inheritMany
v(C.T7,A.ar1)
u(A.W,[C.a8d,C.aAa,C.zw,C.Mb,C.G6,C.TV,C.a4S,C.U_,C.a4Y,C.a4T,C.b6b,C.bBH,C.bBI,C.aVs,C.bBF,C.c0o,C.csn])
u(A.ma,[C.bEt,C.bEu,C.bgV,C.bgW,C.bgY,C.d_A,C.cHq,C.cuD,C.cuC,C.cHo,C.coZ,C.cp7,C.cpd,C.cpJ,C.cpK,C.cpY,C.cpx,C.cpZ,C.cq1,C.cq2,C.cq3,C.cpL,C.cpO,C.cpP,C.cpQ,C.cpR,C.cpS,C.cpT,C.cpU,C.cpW,C.cpX,C.cpc])
v(C.aAU,C.aAa)
v(C.a5W,A.ar4)
v(C.aug,A.wW)
v(C.bgU,A.aAb)
u(A.oz,[C.bgX,C.cHu,C.cHt,C.cHv,C.cHw,C.cHr,C.cHs,C.cHp,C.cuE,C.coT,C.coU,C.coS,C.coW,C.coX,C.coY,C.coV,C.cp_,C.cp0,C.cp1,C.cp3,C.cp4,C.cp5,C.cp6,C.cp2,C.cp8,C.cp9,C.cpa,C.cpb,C.cpe,C.cpf,C.cpA,C.cpz,C.cph,C.cpV,C.cpy,C.cpg,C.cpw,C.cq_,C.cps,C.cpt,C.cpu,C.cq0,C.cpr,C.cpq,C.cpp,C.cpo,C.cpn,C.cpM,C.cpH,C.cpl,C.cpm,C.cpN,C.cpG,C.cpF,C.cpE,C.cpD,C.cpC,C.cpB,C.cpv,C.cpk,C.cpj,C.cpi])
v(C.bgL,C.bgU)
v(C.ME,A.mY)
u(A.IK,[C.yC,C.cHx,C.bBG,C.ZM,C.HY])
v(C.cla,A.WT)
v(C.aa6,A.ak)
v(C.alx,A.ap)
v(C.aiS,C.alx)
u(A.a5n,[C.aMm,C.aOy])
u(A.ar,[C.aln,C.alp])
v(C.Zy,C.aln)
u(A.oA,[C.cuF,C.cpI])
v(C.xn,A.dF)
v(C.aKY,C.alp)
u(A.WH,[C.cHm,C.cHn])
v(C.aLh,C.bBI)
v(C.btd,C.aLh)
v(C.btc,C.bBH)
u(C.bBF,[C.btb,C.b0u,C.bte,C.bta,C.awV])
v(C.H8,A.oB)
v(C.ahh,A.nP)
x(C.aln,A.Hi)
x(C.alp,A.Hi)
x(C.alx,A.hD)
w(C.aLh,C.aVs)})()
A.vD(b.typeUniverse,JSON.parse('{"aAa":{"au":["zw"]},"aAU":{"au":["zw"]},"aug":{"wW":[]},"ME":{"mY":[]},"aa6":{"ak":[],"v":[]},"xn":{"dF":[]},"aiS":{"ap":["aa6"]},"aMm":{"bB":[],"v":[]},"Zy":{"ar":[],"an":[],"bC":[]},"aOy":{"bB":[],"v":[]},"aKY":{"ar":[],"an":[],"bC":[]},"dPz":{"fU":[],"cK":[],"cq":[],"v":[]},"H8":{"ak":[],"v":[]},"ahh":{"ap":["H8"]}}'))
var y=(function rtii(){var x=A.ay
return{E:x("dT<dF>"),P:x("cy<hI?>"),U:x("cy<af<e,@>?>"),J:x("i3<W?>"),d:x("h0<xn>"),a:x("w4"),g:x("lh"),I:x("oG"),L:x("c7"),O:x("cC<Oo,dF>"),r:x("bK"),D:x("kC"),b:x("M2"),Y:x("yC"),V:x("a2<b0>"),c:x("a2<S>"),R:x("a2<lN>"),v:x("a2<iR>"),e:x("a2<am>"),p:x("a2<v>"),k:x("a2<~(dT<dF>)>"),B:x("c5<ap<ak>>"),j:x("Q<@>"),W:x("Q<W?>"),f:x("af<@,@>"),F:x("X<S,v>"),w:x("mK"),K:x("W"),m:x("dD<~(dT<dF>)>"),Z:x("z5"),S:x("dPz"),N:x("e"),h:x("zw"),i:x("mY"),t:x("bF<al>"),u:x("lX"),G:x("e6"),l:x("v"),C:x("fJ"),s:x("cx<am?>"),M:x("bA<mY>"),y:x("IF"),x:x("aM<mY>"),Q:x("Zy"),q:x("qi"),o:x("lA<@>"),cB:x("a7"),z:x("@"),bL:x("F"),_:x("S?"),d0:x("TV?"),cX:x("G6?"),A:x("Q<W?>?"),n:x("af<W?,W?>?"),at:x("i4?"),X:x("W?"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.aqs=new C.b0u()
D.arc=new C.awV()
D.R8=new C.bta()
D.R9=new C.btb()
D.Ra=new C.btd()
D.arD=new C.c0o()
D.Rm=new C.cla()
D.arS=new C.csn()
D.aUJ=new A.y(B.AF,36,B.aI,null,null)
D.asp=new A.d4(B.a4,null,null,D.aUJ,null)
D.aNI=new A.y(B.W7,36,B.aI,null,null)
D.asz=new A.d4(B.a4,null,null,D.aNI,null)
D.ayy=new A.mc(28,null,null,null,null,null)
D.aAH=new A.ai(0,0,10,0)
D.aAW=new A.ai(0,5,8,0)
D.aD3=new A.ai(8,7,8,7)
D.aHw=new A.a1(62848,"MaterialIcons",null,!1)
D.aJ1=new A.a1(983528,"MaterialIcons",null,!1)
D.aG1=new A.a1(57648,"MaterialIcons",null,!1)
D.aK7=new A.y(D.aG1,null,null,null,null)
D.aLs=new A.y(B.rV,null,B.bt,null,null)
D.aOH=new A.y(B.mK,18,B.B,null,null)
D.aRn=new A.y(B.WU,null,null,null,null)
D.aSA=new A.y(B.pR,16,B.bt,null,null)
D.YD=new A.y(B.J1,10,B.B,null,null)
D.aGt=new A.a1(58554,"MaterialIcons",null,!1)
D.aUa=new A.y(D.aGt,null,null,null,null)
D.aXd=new A.b5(null,null,null,null,null,null,null,null,null,null,"\u2022 Fees once paid are non-refundable.\n\u2022 Preserving receipt is mandatory for library access.\n\u2022 Maintain strict silence in study halls.",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,B.a_,!0,null,null,null,null)
D.aGf=new A.a1(58044,"MaterialIcons",null,!1)
D.aUw=new A.y(D.aGf,null,null,null,null)
D.aYw=new A.b5(null,null,null,null,null,null,null,null,null,null,"Thank you for choosing {libraryName} \u2022 Computer-generated receipt",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,D.aUw,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,B.a_,!0,null,null,null,null)
D.aYE=new C.yC(0,"paused")
D.aYF=new C.yC(1,"running")
D.aYG=new C.yC(2,"success")
D.aYH=new C.yC(3,"canceled")
D.aYI=new C.yC(4,"error")
D.bJZ=x([D.aYE,D.aYF,D.aYG,D.aYH,D.aYI],A.ay("a2<yC>"))
D.c9q=new A.be(-12,"-12\xb0 (Authentic)")
D.c9n=new A.be(0,"0\xb0 (Straight)")
D.c95=new A.be(-20,"-20\xb0 (Tilt)")
D.c90=new A.be(12,"+12\xb0 (Right)")
D.bLq=x([D.c9q,D.c9n,D.c95,D.c90],A.ay("a2<+(al,e)>"))
D.bTp=x([B.O5,B.Ec,B.Ed,B.xM,B.O6],A.ay("a2<Cq>"))
D.cTW=new C.ZM(1,"left")
D.akR=new C.xn(D.cTW)
D.cTV=new C.ZM(0,"right")
D.akQ=new C.xn(D.cTV)
D.bYy=new A.cC([B.oi,D.akR,B.oj,D.akQ],y.O)
D.cTX=new C.ZM(2,"up")
D.cRO=new C.xn(D.cTX)
D.cTY=new C.ZM(3,"down")
D.cRP=new C.xn(D.cTY)
D.bYR=new A.cC([B.ol,D.cRO,B.ok,D.cRP,B.oi,D.akR,B.oj,D.akQ],y.O)
D.aCO=new A.ai(4,0,0,8)
D.cD2=new A.f("Tip: Faint (6% - 10%) is recommended for clear reading of printed text without distraction.",null,B.kZ,null,null,null,null,null,null,null,null)
D.c1N=new A.T(D.aCO,D.cD2,null)
D.afx=new C.btc(null)
D.Nn=new C.HY(0,"onlyForDiscrete")
D.agq=new C.HY(1,"onlyForContinuous")
D.agr=new C.HY(2,"always")
D.ags=new C.HY(3,"onDrag")
D.DY=new C.HY(4,"alwaysVisible")
D.agt=new C.HY(5,"never")
D.cf6=new A.cL(null,120,null,null)
D.cfi=new C.bBG(0,"tapAndSlide")
D.cw2=new A.f("\u2728 White paper background removed! Stamp is now a crisp transparent PNG.",null,null,null,null,null,null,null,null,null,null)
D.cfE=new A.bJ(D.cw2,B.V,null,null,null,null,null,null,null,null,null,null,null,B.L,!1,null,null,null,B.z,null)
D.cLi=new A.f("Receipt template settings saved!",null,null,null,null,null,null,null,null,null,null)
D.cg6=new A.bJ(D.cLi,B.V,null,null,null,null,null,null,B.ab,null,null,null,null,B.L,!1,null,null,null,B.z,null)
D.cKF=new A.f("\u2728 White paper background removed! Watermark is now a crisp transparent PNG.",null,null,null,null,null,null,null,null,null,null)
D.chq=new A.bJ(D.cKF,B.V,null,null,null,null,null,null,null,null,null,null,null,B.L,!1,null,null,null,B.z,null)
D.csD=new A.f("Take Photo of Logo",null,null,null,null,null,null,null,null,null,null)
D.ctt=new A.f("Show Helpline & Email",null,B.iF,null,null,null,null,null,null,null,null)
D.ctu=new A.f("Stamp Rotation Angle",null,B.kq,null,null,null,null,null,null,null,null)
D.cui=new A.f("Renders transparent high-res logo alongside title",null,B.dR,null,null,null,null,null,null,null,null)
D.cuI=new A.f("Use Main Library Logo",null,null,null,null,null,null,null,null,null,null)
D.cvq=new A.f("Show Terms & Conditions",null,B.iF,null,null,null,null,null,null,null,null)
D.cwO=new A.f("Presets: ",null,B.ot,null,null,null,null,null,null,null,null)
D.cwT=new A.f("Remove Custom Watermark",null,B.jQ,null,null,null,null,null,null,null,null)
D.cxI=new A.f("Background Watermark Logo",null,B.hH,null,null,null,null,null,null,null,null)
D.cyg=new A.f("Show Library Logo in Header",null,B.iF,null,null,null,null,null,null,null,null)
D.cyq=new A.f("Show Allocated Seat & Hall",null,B.iF,null,null,null,null,null,null,null,null)
D.cz4=new A.f("A4 Full Sheet",null,B.En,null,null,null,null,null,null,null,null)
D.czU=new A.f("Watermark Faintness / Opacity",null,B.kq,null,null,null,null,null,null,null,null)
D.cl0=new A.R(!0,B.bt,null,null,null,null,12,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.cA9=new A.f("Revert to Main Logo",null,D.cl0,null,null,null,null,null,null,null,null)
D.cBD=new A.f("Prints assigned seat number (e.g. Seat #2 (Cozy Hall))",null,B.dR,null,null,null,null,null,null,null,null)
D.cCM=new A.f("Includes non-refundable policy and silent decorum rules",null,B.dR,null,null,null,null,null,null,null,null)
D.cDN=new A.f("Faintly prints your library logo in the center of every receipt to prevent forgery.",null,B.e8,null,null,null,null,null,null,null,null)
D.cEb=new A.f("Take Photo of Stamp",null,null,null,null,null,null,null,null,null,null)
D.cG2=new A.f("Includes authorized signature line below the official seal",null,B.dR,null,null,null,null,null,null,null,null)
D.cGH=new A.f("Syncs watermark with library profile logo",null,null,null,null,null,null,null,null,null,null)
D.cHu=new A.f("Full PDF",null,null,null,null,null,null,null,null,null,null)
D.ajC=new A.f("Auto-Remove Paper Background",null,B.bT,null,null,null,null,null,null,null,null)
D.cJG=new A.f("Remove Stamp",null,B.aiP,null,null,null,null,null,null,null,null)
D.cL0=new A.f("Leave blank to use the standard library non-refundable policy and silent study guidelines.",null,B.ot,null,null,null,null,null,null,null,null)
D.cLJ=new A.f("Remove Stamp",null,B.jQ,null,null,null,null,null,null,null,null)
D.cM0=new A.f("Watermark Size / Coverage",null,B.kq,null,null,null,null,null,null,null,null)
D.cMT=new A.f("Show Authorized Signatory Line",null,B.iF,null,null,null,null,null,null,null,null)
D.ajV=new A.f("Receipt Template",null,null,null,null,null,null,null,null,null,null)
D.cNJ=new A.f("Prints official helpline and reception email under title",null,B.dR,null,null,null,null,null,null,null,null)
D.cNY=new A.f("Stamp Size / Scale",null,B.kq,null,null,null,null,null,null,null,null)
D.cQ1=A.c2("T7")
D.cQp=A.c2("a8d")
D.cQx=A.c2("zw")
D.cQN=A.c2("xn")
D.cVx=new C.cHx(0,"material")})();(function staticFields(){$.dak=A.I(y.N,A.ay("T7"))
$.dL4=A.I(y.N,A.ay("a5W"))
$.dmG=0})();(function lazyInitializers(){var x=a.lazyFinal
x($,"e8k","dg4",()=>new C.b6b(B.d.gc7("")?".":""))})()};
(a=>{a["j7FF+YXka79yDkxe+WANI7NN9Z4="]=a.current})($__dart_deferred_initializers__);