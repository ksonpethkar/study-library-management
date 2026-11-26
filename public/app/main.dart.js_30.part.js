((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
dJJ(){return new B.Gz(null)},
v9:function v9(d,e,f){this.a=d
this.b=e
this.c=f},
Gz:function Gz(d){this.a=d},
aJa:function aJa(d){var _=this
_.w="All"
_.x=d
_.d=$
_.c=_.a=null},
cpv:function cpv(d,e){this.a=d
this.b=e},
cpt:function cpt(d){this.a=d},
cpu:function cpu(d){this.a=d},
cpB:function cpB(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
cpA:function cpA(d,e,f,g,h){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h},
cpx:function cpx(d){this.a=d},
cpw:function cpw(){},
cpy:function cpy(d){this.a=d},
cpz:function cpz(d){this.a=d},
cpS:function cpS(d){this.a=d},
cpR:function cpR(d){this.a=d},
cpT:function cpT(){},
cpZ:function cpZ(d){this.a=d},
cpU:function cpU(d){this.a=d},
cpV:function cpV(d,e){this.a=d
this.b=e},
cpX:function cpX(d){this.a=d},
cpQ:function cpQ(d,e){this.a=d
this.b=e},
cpW:function cpW(){},
cpY:function cpY(d,e,f){this.a=d
this.b=e
this.c=f},
cpP:function cpP(d,e,f){this.a=d
this.b=e
this.c=f},
cpO:function cpO(d,e,f){this.a=d
this.b=e
this.c=f},
cpF:function cpF(){},
cpG:function cpG(){},
cpH:function cpH(){},
cpI:function cpI(){},
cpJ:function cpJ(){},
cpK:function cpK(){},
cpN:function cpN(d){this.a=d},
cpC:function cpC(){},
cpM:function cpM(){},
cpL:function cpL(d,e){this.a=d
this.b=e},
cpD:function cpD(d,e,f){this.a=d
this.b=e
this.c=f},
cpE:function cpE(d,e){this.a=d
this.b=e}},D
J=c[1]
A=c[0]
C=c[2]
E=c[19]
B=a.updateHolder(c[14],B)
D=c[28]
B.v9.prototype={
I(){return this.c.$0()},
gac(){return this.a}}
B.Gz.prototype={
a7(){return new B.aJa(A.a(["All","Students","Receipts & Payments","Plans","Sections","Announcements"],y.s))}}
B.aJa.prototype={
zM(d,e){return this.bpr(d,e)},
bpr(c5,c6){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4
var $async$zM=A.j(function(c7,c8){if(c7===1){t.push(c8)
x=u}for(;;)switch(x){case 0:c0=s.gV().G($.aH(),y.T)
c1=c0==null?"":c0
if(J.ac(c1)===0){x=1
break}a5=c6.h(0,"type")
r=J.L(a5==null?"student":a5).toLowerCase()
q=null
switch(r){case"student":q="students"
break
case"receipt":q="receipts"
break
case"payment":q="payments"
break
case"section":q="sections"
break
case"plan":q="plans"
break
case"announcement":q="announcements"
break
default:q="students"}a5=y.f
a6=y.N
a7=y.z
p=A.d3(a5.b(c6.h(0,"originalData"))?A.d3(a5.a(c6.h(0,"originalData")),a6,a7):A.d3(c6,a6,a7),a6,a7)
J.hk(p,"deletedAt")
J.hk(p,"type")
J.hk(p,"libraryId")
J.hk(p,"displayName")
J.hk(p,"expiresAt")
J.hk(p,"deletedBy")
J.hk(p,"originalData")
J.hk(p,"linkedPayments")
if(J.p(r,"plan"))J.T(p,"deletedAt",null)
x=J.p(r,"student")&&J.k(p,"seatId")!=null?3:4
break
case 3:a8=A.b0(J.k(p,"seatId"))
a9=$.h
b0=(a9==null?$.h=$.K():a9).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
x=5
return A.d(A.a3(new A.J(b0)).m("libraries").u(c1).m("students").bk(0,"seatId",a8).bk(0,"membershipStatus","active").a_(),$async$zM)
case 5:b1=c8
x=b1.ga2().length!==0?6:7
break
case 6:b2=C.h.ga5(b1.ga2()).I().h(0,"name")
if(b2==null)b2="another student"
a9=s.c
if(a9==null){x=1
break}x=8
return A.d(A.bR(null,null,!0,null,new B.cpv(a8,b2),a9,null,!0,!0,y.y),$async$zM)
case 8:if(c8!==!0){x=1
break}J.T(p,"seatId",null)
case 7:case 4:u=10
a9=$.h
b0=(a9==null?$.h=$.K():a9).D("[DEFAULT]")
a9=$.a9()
A.H(b0,a9,!0)
b3=A.a3(new A.J(b0))
o=A.fz(b3,b3.gcH().e8())
b3=$.h
b0=(b3==null?$.h=$.K():b3).D("[DEFAULT]")
A.H(b0,a9,!0)
n=A.a3(new A.J(b0)).m("libraries").u(c1).m(q).u(c5)
b3=$.h
b0=(b3==null?$.h=$.K():b3).D("[DEFAULT]")
A.H(b0,a9,!0)
m=A.a3(new A.J(b0)).m("libraries").u(c1).m("recycle_bin").u(c5)
b3=y.P
o.iF(n,p,A.dH(!0),b3)
o.b.jl(m.gbR())
if(J.p(r,"receipt")){b4=A.bh(c6.h(0,"amount"))
b5=b4==null?null:b4
l=b5==null?0:b5
b4=J.k(p,"status")
k=J.L(b4==null?"active":b4).toLowerCase()
if(l>0&&!J.p(k,"voided")){b4=$.h
b0=(b4==null?$.h=$.K():b4).D("[DEFAULT]")
A.H(b0,a9,!0)
A.avV(o,A.a3(new A.J(b0)),c1,l,1,J.k(p,"createdAt"))}j=c6.h(0,"linkedPayments")
if(y.j.b(j))for(a9=J.bD(j);a9.E();){i=a9.gY()
if(!a5.b(i))continue
h=A.d3(i,a6,a7)
b4=J.k(h,"id")
g=J.L(b4==null?"":b4)
b4=J.ac(g)
b6=$.h
if(b4!==0){b0=(b6==null?$.h=$.K():b6).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
b7=A.a3(new A.J(b0)).m("libraries").u(c1).m("payments").u(g)}else{b0=(b6==null?$.h=$.K():b6).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
b7=A.a3(new A.J(b0)).m("libraries").u(c1).m("payments").fJ()}f=b7
J.T(h,"id",C.h.gai(f.a.b.a))
J.T(h,"aggregateSyncedByClient",!0)
o.iF(f,h,A.dH(!0),b3)}}x=J.p(r,"payment")?13:14
break
case 13:a5=A.bh(c6.h(0,"amount"))
l=a5==null?null:a5
e=l==null?0:l
d=A.C(c6.h(0,"studentId"))
a5=A.C(c6.h(0,"status"))
if(a5==null)a5=""
a0=a5.toLowerCase()
if(e>0&&!J.p(a0,"voided")&&!J.p(a0,"cancelled")&&!J.p(a0,"refunded")){J.T(p,"aggregateSyncedByClient",!0)
o.iF(n,p,A.dH(!0),b3)
a5=$.h
b0=(a5==null?$.h=$.K():a5).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
a5=A.a3(new A.J(b0))
a7=J.k(p,"date")
if(a7==null)a7=J.k(p,"createdAt")
A.avV(o,a5,c1,e,1,a7)}x=e>0&&d!=null&&d.length!==0&&!J.p(a0,"voided")&&!J.p(a0,"refunded")?15:16
break
case 15:u=18
a5=$.h
b0=(a5==null?$.h=$.K():a5).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
x=21
return A.d(A.a3(new A.J(b0)).m("libraries").u(c1).m("students").u(d).a_(),$async$zM)
case 21:a1=c8
if(a1.gb2()){a5=a1.I()
a5=A.bh(a5==null?null:a5.h(0,"pendingDueBalance"))
b8=a5==null?null:a5
a2=b8==null?0:b8
a3=C.l.am(a2-e,0,1/0)
a5=a1.gc5()
a7=$.b2().ak()
o.ea(a5,A.N(["pendingDueBalance",a3,"updatedAt",new A.ai(a7,a7)],a6,y.K),b3)}u=10
x=20
break
case 18:u=17
c2=t.pop()
x=20
break
case 17:x=10
break
case 20:case 16:case 14:x=22
return A.d(o.b.dO(),$async$zM)
case 22:u=24
a5=$.h
b0=(a5==null?$.h=$.K():a5).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
x=27
return A.d(A.a3(new A.J(b0)).m("recycle_bin").u(c5).a.aO(),$async$zM)
case 27:u=10
x=26
break
case 24:u=23
c3=t.pop()
x=26
break
case 23:x=10
break
case 26:a5=s.c
if(a5!=null)a5.L(y.q).f.a3(A.aZ(null,null,null,C.X,C.ad,C.z,null,A.c("Restored "+r.toUpperCase()+" successfully! \u2713",null,null,null,null,null,null,null,null),null,C.L,null,null,null,null,null,null,null,null,null,null))
u=2
x=12
break
case 10:u=9
c4=t.pop()
a4=A.aa(c4)
a5=s.c
if(a5!=null)A.cv(a5,a4,"student")
x=12
break
case 9:x=2
break
case 12:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$zM,w)},
ayz(d,e,f,g){var x=null
return A.bR(x,x,!0,x,new B.cpB(new A.aA(C.as,$.ax()),f,g,e),d,x,!0,!0,y.y)},
GU(d){return this.b5z(d)},
b5z(d){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i
var $async$GU=A.j(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:l=s.gV().G($.aH(),y.T)
k=l==null?"":l
if(J.ac(k)===0){x=1
break}p=s.c
p.toString
x=3
return A.d(s.ayz(p,"This will permanently destroy this record. This action cannot be undone.","DELETE","Delete Forever?"),$async$GU)
case 3:if(f!==!0){x=1
break}u=5
p=$.h
o=(p==null?$.h=$.K():p).D("[DEFAULT]")
p=$.a9()
A.H(o,p,!0)
n=A.a3(new A.J(o))
r=A.fz(n,n.gcH().e8())
n=$.h
o=(n==null?$.h=$.K():n).D("[DEFAULT]")
A.H(o,p,!0)
n=A.a3(new A.J(o)).m("libraries").u(k).m("recycle_bin").u(d)
r.b.jl(n.gbR())
n=$.h
o=(n==null?$.h=$.K():n).D("[DEFAULT]")
A.H(o,p,!0)
n=A.a3(new A.J(o)).m("libraries").u(k).m("plans").u(d)
r.b.jl(n.gbR())
x=8
return A.d(r.b.dO(),$async$GU)
case 8:u=10
n=$.h
o=(n==null?$.h=$.K():n).D("[DEFAULT]")
A.H(o,p,!0)
x=13
return A.d(A.a3(new A.J(o)).m("recycle_bin").u(d).a.aO(),$async$GU)
case 13:u=5
x=12
break
case 10:u=9
j=t.pop()
x=12
break
case 9:x=5
break
case 12:p=s.c
if(p!=null)p.L(y.q).f.a3(D.cdR)
u=2
x=7
break
case 5:u=4
i=t.pop()
q=A.aa(i)
p=s.c
if(p!=null)A.Qn(p,q)
x=7
break
case 4:x=2
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$GU,w)},
wR(d){return this.b75(d)},
b75(a2){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1
var $async$wR=A.j(function(a3,a4){if(a3===1){t.push(a4)
x=u}for(;;)switch(x){case 0:d=s.c
d.toString
x=3
return A.d(s.ayz(d,"This will permanently destroy ALL items in the recycle bin. No data can be restored afterwards.","EMPTY","Empty Recycle Bin?"),$async$wR)
case 3:if(a4!==!0){x=1
break}u=5
d=$.h
i=(d==null?$.h=$.K():d).D("[DEFAULT]")
d=$.a9()
A.H(i,d,!0)
x=8
return A.d(A.a3(new A.J(i)).m("libraries").u(a2).m("recycle_bin").a_(),$async$wR)
case 8:r=a4
h=$.h
i=(h==null?$.h=$.K():h).D("[DEFAULT]")
A.H(i,d,!0)
d=A.a3(new A.J(i))
q=A.fz(d,d.gcH().e8())
for(d=r.ga2(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a0)(d),++g){p=d[g]
f=p.gc5()
q.b.jl(f.gbR())}d=$.h
i=(d==null?$.h=$.K():d).D("[DEFAULT]")
A.H(i,$.a9(),!0)
x=9
return A.d(A.a3(new A.J(i)).m("libraries").u(a2).m("plans").a_(),$async$wR)
case 9:o=a4
for(d=o.ga2(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a0)(d),++g){n=d[g]
if(n.I().h(0,"deletedAt")!=null){f=n.gc5()
q.b.jl(f.gbR())}}x=10
return A.d(q.b.dO(),$async$wR)
case 10:u=12
d=$.h
i=(d==null?$.h=$.K():d).D("[DEFAULT]")
d=$.a9()
A.H(i,d,!0)
x=15
return A.d(A.a3(new A.J(i)).m("recycle_bin").bk(0,"libraryId",a2).a_(),$async$wR)
case 15:m=a4
h=$.h
i=(h==null?$.h=$.K():h).D("[DEFAULT]")
A.H(i,d,!0)
d=A.a3(new A.J(i))
l=A.fz(d,d.gcH().e8())
for(d=m.ga2(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a0)(d),++g){k=d[g]
f=k.gc5()
l.b.jl(f.gbR())}x=16
return A.d(l.b.dO(),$async$wR)
case 16:u=5
x=14
break
case 12:u=11
a0=t.pop()
x=14
break
case 11:x=5
break
case 14:d=s.c
if(d!=null)d.L(y.q).f.a3(D.cev)
u=2
x=7
break
case 5:u=4
a1=t.pop()
j=A.aa(a1)
d=s.c
if(d!=null)A.cv(d,j,"student")
x=7
break
case 4:x=2
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$wR,w)},
P(d){var x,w,v,u,t,s,r,q,p=this,o=null,n="[DEFAULT]",m="libraries",l="recycle_bin",k=p.gV().a4($.aH(),y.T)
if(k==null)k=""
if(k.length===0)return A.fZ(!1,A.c9(A.cq(o,o,o,!0,!0,o,o,1,o,o,o,!1,o,!1,o,o,A.aK(o,o,o,C.bC,o,o,new B.cpR(d),o,o,o,"Back",o),o,!0,o,o,o,o,o,D.UF,o,o,o,1,o,!0),o,E.R6,o,!1,o,o),new B.cpS(d),y.K)
x=$.h
w=(x==null?$.h=$.K():x).D(n)
x=$.a9()
A.H(w,x,!0)
v=A.a3(new A.J(w)).m(m).u(k).m(l).cN()
u=$.h
w=(u==null?$.h=$.K():u).D(n)
A.H(w,x,!0)
t=A.a3(new A.J(w)).m(m).u(k).m("plans").cN()
u=$.h
w=(u==null?$.h=$.K():u).D(n)
A.H(w,x,!0)
s=A.a3(new A.J(w)).m(l).bk(0,"libraryId",k).cN().EC(new B.cpT())
x=A.aK(o,o,o,C.bC,o,o,new B.cpU(d),o,o,o,"Back",o)
u=A.a([A.ey(D.aTq,D.cKA,new B.cpV(p,k),o)],y.p)
r=p.x
q=A.ab(r).i("X<1,jb>")
r=A.Z(new A.X(r,new B.cpW(),q),q.i("aJ.E"))
return A.fZ(!1,A.aoV(A.c9(A.cq(u,o,o,!0,!0,o,A.wQ(o,o,o,2,!0,o,o,o,new B.cpX(p),o,C.kO,r,o,o),1,o,o,o,!1,o,!1,o,o,x,o,!0,o,o,o,o,o,D.UF,o,o,o,1,o,!0),o,A.hv(new B.cpY(p,t,s),o,v,y.C),o,!1,o,o),6),new B.cpZ(d),y.K)}}
var z=a.updateTypes(["a7(v9)","E(v9,v9)"])
B.cpv.prototype={
$1(d){var x=null,w=A.c('Desk "'+this.a+'" is currently assigned to active student "'+A.r(this.b)+'".\n\nTo prevent a double-booking collision, would you like to restore this student with an unassigned seat status?',x,x,x,x,x,x,x,x)
return A.cj(A.a([A.br(C.b1,x,x,x,new B.cpt(d),x,x),A.cE(D.cs6,new B.cpu(d),x)],y.p),x,x,w,x,x,x,D.c8Q,x)},
$S:5}
B.cpt.prototype={
$0(){A.a8(this.a,!1).T(!1)
return null},
$S:0}
B.cpu.prototype={
$0(){A.a8(this.a,!1).T(!0)
return null},
$S:0}
B.cpB.prototype={
$1(d){var x=this
return new A.fL(new B.cpA(x.a,x.b,x.c,x.d,d),null)},
$S:22}
B.cpA.prototype={
$2(d,e){var x,w,v,u=this,t=null,s=u.a,r=C.d.q(s.a.a),q=u.b,p=A.c(u.c,t,t,t,t,C.bD,t,t,t),o=y.p
s=A.A(A.a([A.c(u.d,t,t,t,t,t,t,t,t),C.N,A.c('To confirm, please type "'+q+'" below:',t,t,t,t,A.z(t,t,A.G(d).ax.fy,t,t,t,t,t,t,t,t,t,t,t,C.a1,t,t,!0,t,t,t,t,t,t,t,t),t,t,t),C.P,A.bX(t,C.an,!0,t,!0,C.z,t,A.c_(),s,t,t,t,t,t,2,A.cc(t,C.Z,t,C.cv,t,t,t,t,!0,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,q,t,t,t,t,t,t,t,t,t,!0,!0,!1,t,t,t,t,t,t,t,t,t,t,t,t,t,t),C.J,!0,t,!0,t,!1,t,C.aC,t,t,t,t,t,t,t,t,1,t,t,!1,"\u2022",t,new B.cpx(e),t,t,t,!1,t,t,!1,t,!0,t,C.ah,t,t,t,t,t,t,t,t,t,t,t,t,!0,C.Q,t,C.R,t,t,t,t)],o),C.y,t,C.f,C.C,0,C.o)
x=u.e
w=A.br(C.b1,t,t,t,new B.cpy(x),t,t)
v=A.b3(C.a7,t,t,t,t,t,t,t,t)
return A.cj(A.a([w,A.cE(D.cK8,r.toUpperCase()===q?new B.cpz(x):t,v)],o),t,t,s,t,D.aJJ,t,p,t)},
$S:39}
B.cpx.prototype={
$1(d){return this.a.$1(new B.cpw())},
$S:11}
B.cpw.prototype={
$0(){},
$S:0}
B.cpy.prototype={
$0(){A.a8(this.a,!1).T(!1)
return null},
$S:0}
B.cpz.prototype={
$0(){A.a8(this.a,!1).T(!0)
return null},
$S:0}
B.cpS.prototype={
$2(d,e){var x,w
if(d)return
x=this.a
w=A.ad(x).c
w===$&&A.b()
if(w.co())A.ad(x).T(null)
else A.ad(x).b4("/admin/home",null)},
$S:27}
B.cpR.prototype={
$0(){var x=this.a,w=A.ad(x).c
w===$&&A.b()
return w.co()?A.ad(x).T(null):A.ad(x).b4("/admin/home",null)},
$S:0}
B.cpT.prototype={
$1(d){A.f5().$1("Global bin query note: "+A.r(d))},
$S:6}
B.cpZ.prototype={
$2(d,e){var x,w
if(d)return
x=this.a
w=A.ad(x).c
w===$&&A.b()
if(w.co())A.ad(x).T(null)
else A.ad(x).b4("/admin/home",null)},
$S:27}
B.cpU.prototype={
$0(){var x=this.a,w=A.ad(x).c
w===$&&A.b()
return w.co()?A.ad(x).T(null):A.ad(x).b4("/admin/home",null)},
$S:0}
B.cpV.prototype={
$0(){return this.a.wR(this.b)},
$S:0}
B.cpX.prototype={
$1(d){var x=this.a
x.v(new B.cpQ(x,d))},
$S:30}
B.cpQ.prototype={
$0(){var x=this.a
x.w=x.x[this.b]},
$S:0}
B.cpW.prototype={
$1(d){return A.oZ(null,null,d)},
$S:1824}
B.cpY.prototype={
$2(d,e){var x=null,w=e.c
if(w!=null)return A.aG(new A.V(C.bH,A.A(A.a([D.aR6,C.G,A.c(A.jh(w,x),x,x,x,x,C.E9,C.af,x,x)],y.p),C.k,x,C.f,C.C,0,C.o),x),x,x)
return A.hv(new B.cpP(this.a,this.c,e),x,this.b,y.C)},
$S:94}
B.cpP.prototype={
$2(d,e){return A.hv(new B.cpO(this.a,this.c,e),null,this.b,y.C)},
$S:327}
B.cpO.prototype={
$2(d,a0){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=null,i="originalData",h="type",g="name",f={},e=this.b
if(e.a===C.f0&&e.b==null)return C.ba
x=y.N
w=A.I(x,y.v)
e=e.b
if(e!=null)for(e=e.ga2(),v=e.length,u=y.f,t=y.z,s=0;s<e.length;e.length===v||(0,A.a0)(e),++s){r=e[s]
q=r.I()
if(u.b(q.h(0,i))){p=u.a(q.h(0,i)).fH(0,x,t)
o=A.rW(j,j,x,t)
o.B(0,p)
o.B(0,q)
n=o}else n=q
p=n.h(0,h)
p=J.L(p==null?"student":p)
w.j(0,r.gac(),new B.v9(r.gac(),p.toLowerCase(),n))}e=this.c.b
if(e!=null)for(e=e.ga2(),v=e.length,u=y.z,s=0;s<e.length;e.length===v||(0,A.a0)(e),++s){r=e[s]
m=r.I()
if(m.h(0,"deletedAt")!=null&&!w.aw(r.gac())){t=A.rW(j,j,x,u)
t.B(0,m)
t.j(0,"id",r.gac())
t.j(0,h,"plan")
p=m.h(0,g)
t.j(0,g,p==null?"Plan":p)
p=m.h(0,g)
t.j(0,"displayName",p==null?"Plan":p)
w.j(0,r.gac(),new B.v9(r.gac(),"plan",t))}}e=a0.b
if(e!=null)for(e=e.ga2(),v=e.length,u=y.f,t=y.z,s=0;s<e.length;e.length===v||(0,A.a0)(e),++s){r=e[s]
if(!w.aw(r.gac())){q=r.I()
if(u.b(q.h(0,i))){p=u.a(q.h(0,i)).fH(0,x,t)
o=A.rW(j,j,x,t)
o.B(0,p)
o.B(0,q)
n=o}else n=q
p=n.h(0,h)
p=J.L(p==null?"student":p)
w.j(0,r.gac(),new B.v9(r.gac(),p.toLowerCase(),n))}}e=w.$ti.i("cL<2>")
l=A.Z(new A.cL(w,e),e.i("P.E"))
C.h.cG(l,new B.cpF())
f.a=null
e=this.a
x=e.w
if(x==="Students"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.cpG(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Receipts & Payments"||x==="Receipts"||x==="Payments"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.cpH(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Plans"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.cpI(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Sections"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.cpJ(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Announcements"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.cpK(),x),x.i("P.E"))
f.a=k
x=k}else{f.a=l
x=l}x=x.length
if(x===0){e=e.w
return new A.xQ(C.lv,"No deleted "+(e==="All"?"items":e.toLowerCase())+" found!","Deleted items appear here for 30 days and can be restored anytime.",j,j,j)}return A.kd(A.lI(j,new B.cpL(f,e),x,C.hM,j,new B.cpM(),!1),new B.cpN(e))},
$S:94}
B.cpF.prototype={
$2(d,e){var x,w,v,u="deletedAt",t=d.c.h(0,u),s=e.c.h(0,u)
if(t instanceof A.dZ)x=A.eC(t.gbd())
else x=typeof t=="string"?A.dE(t):null
if(s instanceof A.dZ)w=A.eC(s.gbd())
else w=typeof s=="string"?A.dE(s):null
v=x==null
if(v&&w==null)return 0
if(v)return 1
if(w==null)return-1
return w.b6(0,x)},
$S:z+1}
B.cpG.prototype={
$1(d){return d.b==="student"},
$S:z+0}
B.cpH.prototype={
$1(d){var x=d.b
return x==="receipt"||x==="payment"},
$S:z+0}
B.cpI.prototype={
$1(d){return d.b==="plan"},
$S:z+0}
B.cpJ.prototype={
$1(d){return d.b==="section"},
$S:z+0}
B.cpK.prototype={
$1(d){return d.b==="announcement"},
$S:z+0}
B.cpN.prototype={
$0(){var x=0,w=A.o(y.H),v=this
var $async$$0=A.j(function(d,e){if(d===1)return A.l(e,w)
for(;;)switch(x){case 0:v.a.v(new B.cpC())
x=2
return A.d(A.ha(C.p6,null,y.z),$async$$0)
case 2:return A.m(null,w)}})
return A.n($async$$0,w)},
$S:1}
B.cpC.prototype={
$0(){},
$S:0}
B.cpM.prototype={
$2(d,e){return C.bV},
$S:78}
B.cpL.prototype={
$2(a4,a5){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=null,e="displayName",d="paymentMethod",a0="name",a1=this.a.a[a5],a2=a1.c,a3=a1.b
switch(a3){case"receipt":x=a2.h(0,e)
if(x==null){w=a2.h(0,"receiptNumber")
x="Receipt #"+A.r(w==null?a1.a:w)}w=A.bh(a2.h(0,"amount"))
w=w==null?f:C.l.R(w,0)
w=A.r(w==null?0:w)
v=a2.h(0,d)
u="Amount: \u20b9"+w+" \u2022 Paid via: "+A.r(v==null?"Cash":v)
t=C.d9
s=C.bi
break
case"payment":x=a2.h(0,e)
if(x==null){w=A.bh(a2.h(0,"amount"))
w=w==null?f:C.l.R(w,0)
x="Payment: \u20b9"+A.r(w==null?0:w)}w=a2.h(0,d)
if(w==null)w=a2.h(0,"method")
u="Method: "+A.r(w==null?"Cash":w)
t=C.im
s=C.X
break
case"plan":x=a2.h(0,a0)
if(x==null)x="Plan"
w=A.r(a2.h(0,"price"))
v=A.r(a2.h(0,"duration"))
r=a2.h(0,"durationUnit")
u="Fee: \u20b9"+w+" \u2022 "+v+" "+A.r(r==null?"months":r)
t=C.rw
s=C.ez
break
case"section":x=a2.h(0,a0)
if(x==null)x="Section / Hall"
w=a2.h(0,"totalSeats")
u=A.r(w==null?"Configured":w)+" seats"
t=C.pv
s=C.c7
break
case"announcement":x=a2.h(0,"title")
if(x==null)x="Announcement"
u=a2.h(0,"message")
if(u==null)u=""
t=C.hr
s=C.eA
break
case"student":default:x=a2.h(0,a0)
if(x==null)x="Student"
q=a2.h(0,"phone")
if(q==null)q=""
p=a2.h(0,"seatId")
if(p==null)p=""
w=J.eA(q)?"Phone: "+A.r(q):""
u=w+(J.eA(p)?" \u2022 Seat: "+A.r(p):"")
t=C.fe
s=C.br
break}o=a2.h(0,"deletedAt")
n=""
m=30
if(o!=null){l=o instanceof A.dZ?A.eC(o.gbd()):f
if(typeof o=="string")l=A.dE(o)
if(l!=null){n=A.aM("dd MMM yyyy",f).a9(l)
m=C.j.am(30-C.j.ae(new A.ae(Date.now(),0,!1).c9(l).a,864e8),0,30)}}w=A.cP(s.n(0.12),f,A.Y(t,s,f,f,22),f,f,f)
v=A.c(x,f,f,f,f,C.dC,f,f,f)
r=y.p
k=A.a([],r)
if(u.length!==0)k.push(A.c(u,f,f,f,f,C.E2,f,f,f))
k.push(C.dl)
j=s.n(0.15)
i=A.i(4)
i=A.a([A.w(f,A.c(a3.toUpperCase(),f,f,f,f,A.z(f,f,s,f,f,f,f,f,f,f,f,10,f,f,C.w,f,f,!0,f,f,f,f,f,f,f,f),f,f,f),C.n,f,f,new A.x(j,f,f,i,f,f,C.u),f,f,f,f,C.bK,f,f,f),C.E],r)
if(n.length!==0)i.push(A.c("Deleted: "+n,f,f,f,f,C.kQ,f,f,f))
i.push(C.c4)
j=m<=5
h=j?C.nl:C.f9
g=A.i(4)
i.push(A.w(f,A.c(""+m+" days left",f,f,f,f,A.z(f,f,j?C.ev:C.bn,f,f,f,f,f,f,f,f,10,f,f,C.w,f,f,!0,f,f,f,f,f,f,f,f),f,f,f),C.n,f,f,new A.x(h,f,f,g,f,f,C.u),f,f,f,f,C.bK,f,f,f))
k.push(A.u(i,C.k,C.f,C.i,0,f,f))
i=this.b
return A.bU(!1,f,f,f,!0,f,f,f,!0,f,f,w,f,f,f,f,f,!1,f,f,f,f,f,A.A(k,C.y,f,C.f,C.i,0,C.o),f,f,v,f,A.u(A.a([A.aK(f,f,f,C.XS,f,f,new B.cpD(i,a1,a2),f,f,f,"Restore "+a3,f),A.aK(f,f,f,C.XA,f,f,new B.cpE(i,a1),f,f,f,"Delete Forever",f)],r),C.k,C.f,C.C,0,f,f),f)},
$S:77}
B.cpD.prototype={
$0(){return this.a.zM(this.b.a,this.c)},
$S:0}
B.cpE.prototype={
$0(){return this.a.GU(this.b.a)},
$S:0};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.v9,A.W)
x(B.Gz,A.ot)
x(B.aJa,A.nI)
w(A.m4,[B.cpv,B.cpB,B.cpx,B.cpT,B.cpX,B.cpW,B.cpG,B.cpH,B.cpI,B.cpJ,B.cpK])
w(A.or,[B.cpt,B.cpu,B.cpw,B.cpy,B.cpz,B.cpR,B.cpU,B.cpV,B.cpQ,B.cpN,B.cpC,B.cpD,B.cpE])
w(A.os,[B.cpA,B.cpS,B.cpZ,B.cpY,B.cpP,B.cpO,B.cpF,B.cpM,B.cpL])})()
A.vg(b.typeUniverse,JSON.parse('{"Gz":{"ak":[],"t":[]},"aJa":{"ap":["Gz"]}}'))
var y=(function rtii(){var x=A.az
return{s:x("a2<e>"),p:x("a2<t>"),j:x("Q<@>"),P:x("ag<e,@>"),f:x("ag<@,@>"),K:x("W"),C:x("dl<ag<e,@>>"),N:x("e"),v:x("v9"),q:x("q3"),y:x("a7"),z:x("@"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.cv_=new A.f("Recycle Bin",null,null,null,null,null,null,null,null,null,null)
D.UF=new A.ld(C.co,C.a6,D.cv_,null)
D.aJJ=new A.y(C.da,36,C.a7,null,null)
D.aR6=new A.y(C.jv,48,C.a7,null,null)
D.aTq=new A.y(C.A0,null,C.a7,null,null)
D.aQ5=new A.y(C.da,null,C.bi,null,null)
D.czb=new A.f("Seat Already Occupied",null,null,null,null,null,null,null,null,null,null)
D.bM9=x([D.aQ5,C.E,D.czb],y.p)
D.c8Q=new A.bW(C.aa,C.f,C.i,C.k,null,C.o,null,0,D.bM9,null)
D.cFH=new A.f("Permanently deleted.",null,null,null,null,null,null,null,null,null,null)
D.cdR=new A.bG(D.cFH,null,null,null,null,null,null,null,null,null,null,null,null,C.L,!1,null,null,null,C.z,null)
D.cr6=new A.f("Recycle bin emptied.",null,null,null,null,null,null,null,null,null,null)
D.cev=new A.bG(D.cr6,null,null,null,null,null,null,null,null,null,null,null,null,C.L,!1,null,null,null,C.z,null)
D.cs6=new A.f("Restore Without Seat",null,null,null,null,null,null,null,null,null,null)
D.cK8=new A.f("Delete Permanently",null,null,null,null,null,null,null,null,null,null)
D.cKA=new A.f("Empty All",null,C.jH,null,null,null,null,null,null,null,null)})()};
(a=>{a["IDcIfDqJfQlh0te8sD/K8rLSzYk="]=a.current})($__dart_deferred_initializers__);