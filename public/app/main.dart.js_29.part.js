((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
dO3(){return new B.Hb(null)},
vx:function vx(d,e,f){this.a=d
this.b=e
this.c=f},
Hb:function Hb(d){this.a=d},
aKl:function aKl(d){var _=this
_.w="All"
_.x=d
_.d=$
_.c=_.a=null},
csx:function csx(d,e){this.a=d
this.b=e},
csv:function csv(d){this.a=d},
csw:function csw(d){this.a=d},
csD:function csD(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
csC:function csC(d,e,f,g,h){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h},
csz:function csz(d){this.a=d},
csy:function csy(){},
csA:function csA(d){this.a=d},
csB:function csB(d){this.a=d},
csU:function csU(d){this.a=d},
csT:function csT(d){this.a=d},
csV:function csV(){},
ct0:function ct0(d){this.a=d},
csW:function csW(d){this.a=d},
csX:function csX(d,e){this.a=d
this.b=e},
csZ:function csZ(d){this.a=d},
csS:function csS(d,e){this.a=d
this.b=e},
csY:function csY(){},
ct_:function ct_(d,e,f){this.a=d
this.b=e
this.c=f},
csR:function csR(d,e,f){this.a=d
this.b=e
this.c=f},
csQ:function csQ(d,e,f){this.a=d
this.b=e
this.c=f},
csH:function csH(){},
csI:function csI(){},
csJ:function csJ(){},
csK:function csK(){},
csL:function csL(){},
csM:function csM(){},
csP:function csP(d){this.a=d},
csE:function csE(){},
csO:function csO(){},
csN:function csN(d,e){this.a=d
this.b=e},
csF:function csF(d,e,f){this.a=d
this.b=e
this.c=f},
csG:function csG(d,e){this.a=d
this.b=e}},D
J=c[1]
A=c[0]
C=c[2]
E=c[19]
B=a.updateHolder(c[14],B)
D=c[25]
B.vx.prototype={
I(){return this.c.$0()},
gad(){return this.a}}
B.Hb.prototype={
a6(){return new B.aKl(A.a(["All","Students","Receipts & Payments","Plans","Sections","Announcements"],y.s))}}
B.aKl.prototype={
A2(d,e){return this.brc(d,e)},
brc(c5,c6){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4
var $async$A2=A.j(function(c7,c8){if(c7===1){t.push(c8)
x=u}for(;;)switch(x){case 0:c0=s.gV().G($.aE(),y.T)
c1=c0==null?"":c0
if(J.ac(c1)===0){x=1
break}a5=c6.h(0,"type")
r=J.K(a5==null?"student":a5).toLowerCase()
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
p=A.d7(a5.b(c6.h(0,"originalData"))?A.d7(a5.a(c6.h(0,"originalData")),a6,a7):A.d7(c6,a6,a7),a6,a7)
J.hs(p,"deletedAt")
J.hs(p,"type")
J.hs(p,"libraryId")
J.hs(p,"displayName")
J.hs(p,"expiresAt")
J.hs(p,"deletedBy")
J.hs(p,"originalData")
J.hs(p,"linkedPayments")
if(J.p(r,"plan"))J.V(p,"deletedAt",null)
x=J.p(r,"student")&&J.k(p,"seatId")!=null?3:4
break
case 3:a8=A.b3(J.k(p,"seatId"))
a9=$.h
b0=(a9==null?$.h=$.M():a9).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
x=5
return A.d(A.a4(new A.L(b0)).n("libraries").v(c1).n("students").bp(0,"seatId",a8).bp(0,"membershipStatus","active").a_(),$async$A2)
case 5:b1=c8
x=b1.ga3().length!==0?6:7
break
case 6:b2=C.h.ga5(b1.ga3()).I().h(0,"name")
if(b2==null)b2="another student"
a9=s.c
if(a9==null){x=1
break}x=8
return A.d(A.bP(null,null,!0,null,new B.csx(a8,b2),a9,null,!0,!0,y.y),$async$A2)
case 8:if(c8!==!0){x=1
break}J.V(p,"seatId",null)
case 7:case 4:u=10
a9=$.h
b0=(a9==null?$.h=$.M():a9).D("[DEFAULT]")
a9=$.a9()
A.H(b0,a9,!0)
b3=A.a4(new A.L(b0))
o=A.fv(b3,b3.gcH().e5())
b3=$.h
b0=(b3==null?$.h=$.M():b3).D("[DEFAULT]")
A.H(b0,a9,!0)
n=A.a4(new A.L(b0)).n("libraries").v(c1).n(q).v(c5)
b3=$.h
b0=(b3==null?$.h=$.M():b3).D("[DEFAULT]")
A.H(b0,a9,!0)
m=A.a4(new A.L(b0)).n("libraries").v(c1).n("recycle_bin").v(c5)
b3=y.P
o.iK(n,p,A.dz(!0),b3)
o.b.js(m.gbT())
if(J.p(r,"receipt")){b4=A.bf(c6.h(0,"amount"))
b5=b4==null?null:b4
l=b5==null?0:b5
b4=J.k(p,"status")
k=J.K(b4==null?"active":b4).toLowerCase()
if(l>0&&!J.p(k,"voided")){b4=$.h
b0=(b4==null?$.h=$.M():b4).D("[DEFAULT]")
A.H(b0,a9,!0)
A.awY(o,A.a4(new A.L(b0)),c1,l,1,J.k(p,"createdAt"))}j=c6.h(0,"linkedPayments")
if(y.j.b(j))for(a9=J.bD(j);a9.E();){i=a9.gY()
if(!a5.b(i))continue
h=A.d7(i,a6,a7)
b4=J.k(h,"id")
g=J.K(b4==null?"":b4)
b4=J.ac(g)
b6=$.h
if(b4!==0){b0=(b6==null?$.h=$.M():b6).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
b7=A.a4(new A.L(b0)).n("libraries").v(c1).n("payments").v(g)}else{b0=(b6==null?$.h=$.M():b6).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
b7=A.a4(new A.L(b0)).n("libraries").v(c1).n("payments").fP()}f=b7
J.V(h,"id",C.h.gaj(f.a.b.a))
J.V(h,"aggregateSyncedByClient",!0)
o.iK(f,h,A.dz(!0),b3)}}x=J.p(r,"payment")?13:14
break
case 13:a5=A.bf(c6.h(0,"amount"))
l=a5==null?null:a5
e=l==null?0:l
d=A.D(c6.h(0,"studentId"))
a5=A.D(c6.h(0,"status"))
if(a5==null)a5=""
a0=a5.toLowerCase()
if(e>0&&!J.p(a0,"voided")&&!J.p(a0,"cancelled")&&!J.p(a0,"refunded")){J.V(p,"aggregateSyncedByClient",!0)
o.iK(n,p,A.dz(!0),b3)
a5=$.h
b0=(a5==null?$.h=$.M():a5).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
a5=A.a4(new A.L(b0))
a7=J.k(p,"date")
if(a7==null)a7=J.k(p,"createdAt")
A.awY(o,a5,c1,e,1,a7)}x=e>0&&d!=null&&d.length!==0&&!J.p(a0,"voided")&&!J.p(a0,"refunded")?15:16
break
case 15:u=18
a5=$.h
b0=(a5==null?$.h=$.M():a5).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
x=21
return A.d(A.a4(new A.L(b0)).n("libraries").v(c1).n("students").v(d).a_(),$async$A2)
case 21:a1=c8
if(a1.gb2()){a5=a1.I()
a5=A.bf(a5==null?null:a5.h(0,"pendingDueBalance"))
b8=a5==null?null:a5
a2=b8==null?0:b8
a3=C.l.a9(a2-e,0,1/0)
a5=a1.gc4()
a7=$.b1().ak()
o.e_(a5,A.N(["pendingDueBalance",a3,"updatedAt",new A.aj(a7,a7)],a6,y.K),b3)}u=10
x=20
break
case 18:u=17
c2=t.pop()
x=20
break
case 17:x=10
break
case 20:case 16:case 14:x=22
return A.d(o.b.dI(),$async$A2)
case 22:u=24
a5=$.h
b0=(a5==null?$.h=$.M():a5).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
x=27
return A.d(A.a4(new A.L(b0)).n("recycle_bin").v(c5).a.aM(),$async$A2)
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
if(a5!=null)a5.M(y.q).f.a2(A.aV(null,null,null,C.V,C.ab,C.z,null,A.c("Restored "+r.toUpperCase()+" successfully! \u2713",null,null,null,null,null,null,null,null),null,C.L,null,null,null,null,null,null,null,null,null,null))
u=2
x=12
break
case 10:u=9
c4=t.pop()
a4=A.aa(c4)
a5=s.c
if(a5!=null)A.cs(a5,a4,"student")
x=12
break
case 9:x=2
break
case 12:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$A2,w)},
azx(d,e,f,g){var x=null
return A.bP(x,x,!0,x,new B.csD(new A.aA(C.as,$.ax()),f,g,e),d,x,!0,!0,y.y)},
Hk(d){return this.b70(d)},
b70(d){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i
var $async$Hk=A.j(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:l=s.gV().G($.aE(),y.T)
k=l==null?"":l
if(J.ac(k)===0){x=1
break}p=s.c
p.toString
x=3
return A.d(s.azx(p,"This will permanently destroy this record. This action cannot be undone.","DELETE","Delete Forever?"),$async$Hk)
case 3:if(f!==!0){x=1
break}u=5
p=$.h
o=(p==null?$.h=$.M():p).D("[DEFAULT]")
p=$.a9()
A.H(o,p,!0)
n=A.a4(new A.L(o))
r=A.fv(n,n.gcH().e5())
n=$.h
o=(n==null?$.h=$.M():n).D("[DEFAULT]")
A.H(o,p,!0)
n=A.a4(new A.L(o)).n("libraries").v(k).n("recycle_bin").v(d)
r.b.js(n.gbT())
n=$.h
o=(n==null?$.h=$.M():n).D("[DEFAULT]")
A.H(o,p,!0)
n=A.a4(new A.L(o)).n("libraries").v(k).n("plans").v(d)
r.b.js(n.gbT())
x=8
return A.d(r.b.dI(),$async$Hk)
case 8:u=10
n=$.h
o=(n==null?$.h=$.M():n).D("[DEFAULT]")
A.H(o,p,!0)
x=13
return A.d(A.a4(new A.L(o)).n("recycle_bin").v(d).a.aM(),$async$Hk)
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
if(p!=null)p.M(y.q).f.a2(D.cgd)
u=2
x=7
break
case 5:u=4
i=t.pop()
q=A.aa(i)
p=s.c
if(p!=null)A.Rb(p,q)
x=7
break
case 4:x=2
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$Hk,w)},
wX(d){return this.b8y(d)},
b8y(a2){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1
var $async$wX=A.j(function(a3,a4){if(a3===1){t.push(a4)
x=u}for(;;)switch(x){case 0:d=s.c
d.toString
x=3
return A.d(s.azx(d,"This will permanently destroy ALL items in the recycle bin. No data can be restored afterwards.","EMPTY","Empty Recycle Bin?"),$async$wX)
case 3:if(a4!==!0){x=1
break}u=5
d=$.h
i=(d==null?$.h=$.M():d).D("[DEFAULT]")
d=$.a9()
A.H(i,d,!0)
x=8
return A.d(A.a4(new A.L(i)).n("libraries").v(a2).n("recycle_bin").a_(),$async$wX)
case 8:r=a4
h=$.h
i=(h==null?$.h=$.M():h).D("[DEFAULT]")
A.H(i,d,!0)
d=A.a4(new A.L(i))
q=A.fv(d,d.gcH().e5())
for(d=r.ga3(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a0)(d),++g){p=d[g]
f=p.gc4()
q.b.js(f.gbT())}d=$.h
i=(d==null?$.h=$.M():d).D("[DEFAULT]")
A.H(i,$.a9(),!0)
x=9
return A.d(A.a4(new A.L(i)).n("libraries").v(a2).n("plans").a_(),$async$wX)
case 9:o=a4
for(d=o.ga3(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a0)(d),++g){n=d[g]
if(n.I().h(0,"deletedAt")!=null){f=n.gc4()
q.b.js(f.gbT())}}x=10
return A.d(q.b.dI(),$async$wX)
case 10:u=12
d=$.h
i=(d==null?$.h=$.M():d).D("[DEFAULT]")
d=$.a9()
A.H(i,d,!0)
x=15
return A.d(A.a4(new A.L(i)).n("recycle_bin").bp(0,"libraryId",a2).a_(),$async$wX)
case 15:m=a4
h=$.h
i=(h==null?$.h=$.M():h).D("[DEFAULT]")
A.H(i,d,!0)
d=A.a4(new A.L(i))
l=A.fv(d,d.gcH().e5())
for(d=m.ga3(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a0)(d),++g){k=d[g]
f=k.gc4()
l.b.js(f.gbT())}x=16
return A.d(l.b.dI(),$async$wX)
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
if(d!=null)d.M(y.q).f.a2(D.cgS)
u=2
x=7
break
case 5:u=4
a1=t.pop()
j=A.aa(a1)
d=s.c
if(d!=null)A.cs(d,j,"student")
x=7
break
case 4:x=2
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$wX,w)},
P(d){var x,w,v,u,t,s,r,q,p=this,o=null,n="[DEFAULT]",m="libraries",l="recycle_bin",k=p.gV().a4($.aE(),y.T)
if(k==null)k=""
if(k.length===0)return A.h4(!1,A.cf(A.cu(o,o,o,!0,!0,o,o,1,o,o,o,!1,o,!1,o,o,A.aK(o,o,o,C.bI,o,o,new B.csT(d),o,o,o,"Back",o),o,!0,o,o,o,o,o,D.Vf,o,o,o,1,o,!0),o,E.RF,o,!1,o,o),new B.csU(d),y.K)
x=$.h
w=(x==null?$.h=$.M():x).D(n)
x=$.a9()
A.H(w,x,!0)
v=A.a4(new A.L(w)).n(m).v(k).n(l).cQ()
u=$.h
w=(u==null?$.h=$.M():u).D(n)
A.H(w,x,!0)
t=A.a4(new A.L(w)).n(m).v(k).n("plans").cQ()
u=$.h
w=(u==null?$.h=$.M():u).D(n)
A.H(w,x,!0)
s=A.a4(new A.L(w)).n(l).bp(0,"libraryId",k).cQ().EX(new B.csV())
x=A.aK(o,o,o,C.bI,o,o,new B.csW(d),o,o,o,"Back",o)
u=A.a([A.eq(D.aUQ,D.cNx,new B.csX(p,k),o)],y.p)
r=p.x
q=A.ab(r).i("Y<1,jn>")
r=A.Z(new A.Y(r,new B.csY(),q),q.i("aJ.E"))
return A.h4(!1,A.apX(A.cf(A.cu(u,o,o,!0,!0,o,A.xd(o,o,o,2,!0,o,o,o,new B.csZ(p),o,C.kX,r,o,o),1,o,o,o,!1,o,!1,o,o,x,o,!0,o,o,o,o,o,D.Vf,o,o,o,1,o,!0),o,A.hy(new B.ct_(p,t,s),o,v,y.C),o,!1,o,o),6),new B.ct0(d),y.K)}}
var z=a.updateTypes(["a7(vx)","F(vx,vx)"])
B.csx.prototype={
$1(d){var x=null,w=A.c('Desk "'+this.a+'" is currently assigned to active student "'+A.q(this.b)+'".\n\nTo prevent a double-booking collision, would you like to restore this student with an unassigned seat status?',x,x,x,x,x,x,x,x)
return A.ci(A.a([A.bp(C.b1,x,x,x,new B.csv(d),x,x),A.cA(D.cuJ,new B.csw(d),x)],y.p),x,x,w,x,x,x,D.cb8,x)},
$S:6}
B.csv.prototype={
$0(){A.a8(this.a,!1).R(!1)
return null},
$S:0}
B.csw.prototype={
$0(){A.a8(this.a,!1).R(!0)
return null},
$S:0}
B.csD.prototype={
$1(d){var x=this
return new A.fO(new B.csC(x.a,x.b,x.c,x.d,d),null)},
$S:20}
B.csC.prototype={
$2(d,e){var x,w,v,u=this,t=null,s=u.a,r=C.d.q(s.a.a),q=u.b,p=A.c(u.c,t,t,t,t,C.bJ,t,t,t),o=y.p
s=A.z(A.a([A.c(u.d,t,t,t,t,t,t,t,t),C.P,A.c('To confirm, please type "'+q+'" below:',t,t,t,t,A.A(t,t,A.G(d).ax.fy,t,t,t,t,t,t,t,t,t,t,t,C.a1,t,t,!0,t,t,t,t,t,t,t,t),t,t,t),C.N,A.bU(t,C.ak,!0,t,!0,C.z,t,A.bW(),s,t,t,t,t,t,2,A.ce(t,C.a_,t,C.cw,t,t,t,t,!0,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,q,t,t,t,t,t,t,t,t,t,!0,!0,!1,t,t,t,t,t,t,t,t,t,t,t,t,t,t),C.J,!0,t,!0,t,!1,t,C.aB,t,t,t,t,t,t,t,t,1,t,t,!1,"\u2022",t,new B.csz(e),t,t,t,!1,t,t,!1,t,!0,t,C.ag,t,t,t,t,t,t,t,t,t,t,t,t,!0,C.Q,t,C.R,t,t,t,t)],o),C.x,t,C.f,C.C,0,C.o)
x=u.e
w=A.bp(C.b1,t,t,t,new B.csA(x),t,t)
v=A.b4(C.a7,t,t,t,t,t,t,t,t)
return A.ci(A.a([w,A.cA(D.cN4,r.toUpperCase()===q?new B.csB(x):t,v)],o),t,t,s,t,D.aL1,t,p,t)},
$S:39}
B.csz.prototype={
$1(d){return this.a.$1(new B.csy())},
$S:8}
B.csy.prototype={
$0(){},
$S:0}
B.csA.prototype={
$0(){A.a8(this.a,!1).R(!1)
return null},
$S:0}
B.csB.prototype={
$0(){A.a8(this.a,!1).R(!0)
return null},
$S:0}
B.csU.prototype={
$2(d,e){var x,w
if(d)return
x=this.a
w=A.ae(x).c
w===$&&A.b()
if(w.cs())A.ae(x).R(null)
else A.ae(x).b5("/admin/home",null)},
$S:27}
B.csT.prototype={
$0(){var x=this.a,w=A.ae(x).c
w===$&&A.b()
return w.cs()?A.ae(x).R(null):A.ae(x).b5("/admin/home",null)},
$S:0}
B.csV.prototype={
$1(d){A.f4().$1("Global bin query note: "+A.q(d))},
$S:5}
B.ct0.prototype={
$2(d,e){var x,w
if(d)return
x=this.a
w=A.ae(x).c
w===$&&A.b()
if(w.cs())A.ae(x).R(null)
else A.ae(x).b5("/admin/home",null)},
$S:27}
B.csW.prototype={
$0(){var x=this.a,w=A.ae(x).c
w===$&&A.b()
return w.cs()?A.ae(x).R(null):A.ae(x).b5("/admin/home",null)},
$S:0}
B.csX.prototype={
$0(){return this.a.wX(this.b)},
$S:0}
B.csZ.prototype={
$1(d){var x=this.a
x.u(new B.csS(x,d))},
$S:29}
B.csS.prototype={
$0(){var x=this.a
x.w=x.x[this.b]},
$S:0}
B.csY.prototype={
$1(d){return A.p9(null,null,d)},
$S:1859}
B.ct_.prototype={
$2(d,e){var x=null,w=e.c
if(w!=null)return A.aF(new A.T(C.bH,A.z(A.a([D.aSw,C.F,A.c(A.jt(w,x),x,x,x,x,C.Eq,C.ah,x,x)],y.p),C.k,x,C.f,C.C,0,C.o),x),x,x)
return A.hy(new B.csR(this.a,this.c,e),x,this.b,y.C)},
$S:92}
B.csR.prototype={
$2(d,e){return A.hy(new B.csQ(this.a,this.c,e),null,this.b,y.C)},
$S:293}
B.csQ.prototype={
$2(d,a0){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=null,i="originalData",h="type",g="name",f={},e=this.b
if(e.a===C.fb&&e.b==null)return C.ba
x=y.N
w=A.I(x,y.v)
e=e.b
if(e!=null)for(e=e.ga3(),v=e.length,u=y.f,t=y.z,s=0;s<e.length;e.length===v||(0,A.a0)(e),++s){r=e[s]
q=r.I()
if(u.b(q.h(0,i))){p=u.a(q.h(0,i)).fN(0,x,t)
o=A.td(j,j,x,t)
o.B(0,p)
o.B(0,q)
n=o}else n=q
p=n.h(0,h)
p=J.K(p==null?"student":p)
w.j(0,r.gad(),new B.vx(r.gad(),p.toLowerCase(),n))}e=this.c.b
if(e!=null)for(e=e.ga3(),v=e.length,u=y.z,s=0;s<e.length;e.length===v||(0,A.a0)(e),++s){r=e[s]
m=r.I()
if(m.h(0,"deletedAt")!=null&&!w.ar(r.gad())){t=A.td(j,j,x,u)
t.B(0,m)
t.j(0,"id",r.gad())
t.j(0,h,"plan")
p=m.h(0,g)
t.j(0,g,p==null?"Plan":p)
p=m.h(0,g)
t.j(0,"displayName",p==null?"Plan":p)
w.j(0,r.gad(),new B.vx(r.gad(),"plan",t))}}e=a0.b
if(e!=null)for(e=e.ga3(),v=e.length,u=y.f,t=y.z,s=0;s<e.length;e.length===v||(0,A.a0)(e),++s){r=e[s]
if(!w.ar(r.gad())){q=r.I()
if(u.b(q.h(0,i))){p=u.a(q.h(0,i)).fN(0,x,t)
o=A.td(j,j,x,t)
o.B(0,p)
o.B(0,q)
n=o}else n=q
p=n.h(0,h)
p=J.K(p==null?"student":p)
w.j(0,r.gad(),new B.vx(r.gad(),p.toLowerCase(),n))}}e=w.$ti.i("cP<2>")
l=A.Z(new A.cP(w,e),e.i("P.E"))
C.h.cK(l,new B.csH())
f.a=null
e=this.a
x=e.w
if(x==="Students"){x=A.ab(l).i("av<1>")
k=A.Z(new A.av(l,new B.csI(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Receipts & Payments"||x==="Receipts"||x==="Payments"){x=A.ab(l).i("av<1>")
k=A.Z(new A.av(l,new B.csJ(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Plans"){x=A.ab(l).i("av<1>")
k=A.Z(new A.av(l,new B.csK(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Sections"){x=A.ab(l).i("av<1>")
k=A.Z(new A.av(l,new B.csL(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Announcements"){x=A.ab(l).i("av<1>")
k=A.Z(new A.av(l,new B.csM(),x),x.i("P.E"))
f.a=k
x=k}else{f.a=l
x=l}x=x.length
if(x===0){e=e.w
return new A.yk(C.lD,"No deleted "+(e==="All"?"items":e.toLowerCase())+" found!","Deleted items appear here for 30 days and can be restored anytime.",j,j,j)}return A.kh(A.lo(j,new B.csN(f,e),x,C.hV,j,new B.csO(),!1),new B.csP(e))},
$S:92}
B.csH.prototype={
$2(d,e){var x,w,v,u="deletedAt",t=d.c.h(0,u),s=e.c.h(0,u)
if(t instanceof A.dY)x=A.eG(t.gbe())
else x=typeof t=="string"?A.dB(t):null
if(s instanceof A.dY)w=A.eG(s.gbe())
else w=typeof s=="string"?A.dB(s):null
v=x==null
if(v&&w==null)return 0
if(v)return 1
if(w==null)return-1
return w.b8(0,x)},
$S:z+1}
B.csI.prototype={
$1(d){return d.b==="student"},
$S:z+0}
B.csJ.prototype={
$1(d){var x=d.b
return x==="receipt"||x==="payment"},
$S:z+0}
B.csK.prototype={
$1(d){return d.b==="plan"},
$S:z+0}
B.csL.prototype={
$1(d){return d.b==="section"},
$S:z+0}
B.csM.prototype={
$1(d){return d.b==="announcement"},
$S:z+0}
B.csP.prototype={
$0(){var x=0,w=A.o(y.H),v=this
var $async$$0=A.j(function(d,e){if(d===1)return A.l(e,w)
for(;;)switch(x){case 0:v.a.u(new B.csE())
x=2
return A.d(A.hg(C.pj,null,y.z),$async$$0)
case 2:return A.m(null,w)}})
return A.n($async$$0,w)},
$S:1}
B.csE.prototype={
$0(){},
$S:0}
B.csO.prototype={
$2(d,e){return C.bY},
$S:88}
B.csN.prototype={
$2(a4,a5){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=null,e="displayName",d="paymentMethod",a0="name",a1=this.a.a[a5],a2=a1.c,a3=a1.b
switch(a3){case"receipt":x=a2.h(0,e)
if(x==null){w=a2.h(0,"receiptNumber")
x="Receipt #"+A.q(w==null?a1.a:w)}w=A.bf(a2.h(0,"amount"))
w=w==null?f:C.l.S(w,0)
w=A.q(w==null?0:w)
v=a2.h(0,d)
u="Amount: \u20b9"+w+" \u2022 Paid via: "+A.q(v==null?"Cash":v)
t=C.de
s=C.bk
break
case"payment":x=a2.h(0,e)
if(x==null){w=A.bf(a2.h(0,"amount"))
w=w==null?f:C.l.S(w,0)
x="Payment: \u20b9"+A.q(w==null?0:w)}w=a2.h(0,d)
if(w==null)w=a2.h(0,"method")
u="Method: "+A.q(w==null?"Cash":w)
t=C.it
s=C.V
break
case"plan":x=a2.h(0,a0)
if(x==null)x="Plan"
w=A.q(a2.h(0,"price"))
v=A.q(a2.h(0,"duration"))
r=a2.h(0,"durationUnit")
u="Fee: \u20b9"+w+" \u2022 "+v+" "+A.q(r==null?"months":r)
t=C.rW
s=C.eI
break
case"section":x=a2.h(0,a0)
if(x==null)x="Section / Hall"
w=a2.h(0,"totalSeats")
u=A.q(w==null?"Configured":w)+" seats"
t=C.pS
s=C.c9
break
case"announcement":x=a2.h(0,"title")
if(x==null)x="Announcement"
u=a2.h(0,"message")
if(u==null)u=""
t=C.hC
s=C.eJ
break
case"student":default:x=a2.h(0,a0)
if(x==null)x="Student"
q=a2.h(0,"phone")
if(q==null)q=""
p=a2.h(0,"seatId")
if(p==null)p=""
w=J.eE(q)?"Phone: "+A.q(q):""
u=w+(J.eE(p)?" \u2022 Seat: "+A.q(p):"")
t=C.fm
s=C.bt
break}o=a2.h(0,"deletedAt")
n=""
m=30
if(o!=null){l=o instanceof A.dY?A.eG(o.gbe()):f
if(typeof o=="string")l=A.dB(o)
if(l!=null){n=A.aL("dd MMM yyyy",f).aa(l)
m=C.j.a9(30-C.j.af(new A.ad(Date.now(),0,!1).cb(l).a,864e8),0,30)}}w=A.cU(s.m(0.12),f,A.W(t,s,f,f,22),f,f,f)
v=A.c(x,f,f,f,f,C.dK,f,f,f)
r=y.p
k=A.a([],r)
if(u.length!==0)k.push(A.c(u,f,f,f,f,C.xR,f,f,f))
k.push(C.db)
j=s.m(0.15)
i=A.i(4)
i=A.a([A.w(f,A.c(a3.toUpperCase(),f,f,f,f,A.A(f,f,s,f,f,f,f,f,f,f,f,10,f,f,C.w,f,f,!0,f,f,f,f,f,f,f,f),f,f,f),C.n,f,f,new A.x(j,f,f,i,f,f,C.u),f,f,f,f,C.bK,f,f,f),C.D],r)
if(n.length!==0)i.push(A.c("Deleted: "+n,f,f,f,f,C.kZ,f,f,f))
i.push(C.c7)
j=m<=5
h=j?C.nv:C.fi
g=A.i(4)
i.push(A.w(f,A.c(""+m+" days left",f,f,f,f,A.A(f,f,j?C.eE:C.bn,f,f,f,f,f,f,f,f,10,f,f,C.w,f,f,!0,f,f,f,f,f,f,f,f),f,f,f),C.n,f,f,new A.x(h,f,f,g,f,f,C.u),f,f,f,f,C.bK,f,f,f))
k.push(A.u(i,C.k,C.f,C.i,0,f,f))
i=this.b
return A.bZ(!1,f,f,f,!0,f,f,f,!0,f,f,w,f,f,f,f,f,!1,f,f,f,f,f,A.z(k,C.x,f,C.f,C.i,0,C.o),f,f,v,f,A.u(A.a([A.aK(f,f,f,C.Yx,f,f,new B.csF(i,a1,a2),f,f,f,"Restore "+a3,f),A.aK(f,f,f,C.Ye,f,f,new B.csG(i,a1),f,f,f,"Delete Forever",f)],r),C.k,C.f,C.C,0,f,f),f)},
$S:81}
B.csF.prototype={
$0(){return this.a.A2(this.b.a,this.c)},
$S:0}
B.csG.prototype={
$0(){return this.a.Hk(this.b.a)},
$S:0};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.vx,A.X)
x(B.Hb,A.oB)
x(B.aKl,A.nP)
w(A.ma,[B.csx,B.csD,B.csz,B.csV,B.csZ,B.csY,B.csI,B.csJ,B.csK,B.csL,B.csM])
w(A.oz,[B.csv,B.csw,B.csy,B.csA,B.csB,B.csT,B.csW,B.csX,B.csS,B.csP,B.csE,B.csF,B.csG])
w(A.oA,[B.csC,B.csU,B.ct0,B.ct_,B.csR,B.csQ,B.csH,B.csO,B.csN])})()
A.vE(b.typeUniverse,JSON.parse('{"Hb":{"ak":[],"v":[]},"aKl":{"ap":["Hb"]}}'))
var y=(function rtii(){var x=A.ay
return{s:x("a2<e>"),p:x("a2<v>"),j:x("Q<@>"),P:x("af<e,@>"),f:x("af<@,@>"),K:x("X"),C:x("dl<af<e,@>>"),N:x("e"),v:x("vx"),q:x("qi"),y:x("a7"),z:x("@"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.cxG=new A.f("Recycle Bin",null,null,null,null,null,null,null,null,null,null)
D.Vf=new A.lk(C.cn,C.a4,D.cxG,null)
D.aL1=new A.y(C.cX,36,C.a7,null,null)
D.aSw=new A.y(C.kg,48,C.a7,null,null)
D.aUQ=new A.y(C.Al,null,C.a7,null,null)
D.aRv=new A.y(C.cX,null,C.bk,null,null)
D.cBX=new A.f("Seat Already Occupied",null,null,null,null,null,null,null,null,null,null)
D.bNV=x([D.aRv,C.D,D.cBX],y.p)
D.cb8=new A.c3(C.ac,C.f,C.i,C.k,null,C.o,null,0,D.bNV,null)
D.cIB=new A.f("Permanently deleted.",null,null,null,null,null,null,null,null,null,null)
D.cgd=new A.bJ(D.cIB,null,null,null,null,null,null,null,null,null,null,null,null,C.L,!1,null,null,null,C.z,null)
D.ctH=new A.f("Recycle bin emptied.",null,null,null,null,null,null,null,null,null,null)
D.cgS=new A.bJ(D.ctH,null,null,null,null,null,null,null,null,null,null,null,null,C.L,!1,null,null,null,C.z,null)
D.cuJ=new A.f("Restore Without Seat",null,null,null,null,null,null,null,null,null,null)
D.cN4=new A.f("Delete Permanently",null,null,null,null,null,null,null,null,null,null)
D.cNx=new A.f("Empty All",null,C.jQ,null,null,null,null,null,null,null,null)})()};
(a=>{a["3WYptrn3zKEpO2RH/faKMHsUX0o="]=a.current})($__dart_deferred_initializers__);