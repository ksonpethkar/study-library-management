((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
dNg(){return new B.H7(null)},
vw:function vw(d,e,f){this.a=d
this.b=e
this.c=f},
H7:function H7(d){this.a=d},
aK7:function aK7(d){var _=this
_.w="All"
_.x=d
_.d=$
_.c=_.a=null},
cs8:function cs8(d,e){this.a=d
this.b=e},
cs6:function cs6(d){this.a=d},
cs7:function cs7(d){this.a=d},
cse:function cse(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
csd:function csd(d,e,f,g,h){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h},
csa:function csa(d){this.a=d},
cs9:function cs9(){},
csb:function csb(d){this.a=d},
csc:function csc(d){this.a=d},
csv:function csv(d){this.a=d},
csu:function csu(d){this.a=d},
csw:function csw(){},
csC:function csC(d){this.a=d},
csx:function csx(d){this.a=d},
csy:function csy(d,e){this.a=d
this.b=e},
csA:function csA(d){this.a=d},
cst:function cst(d,e){this.a=d
this.b=e},
csz:function csz(){},
csB:function csB(d,e,f){this.a=d
this.b=e
this.c=f},
css:function css(d,e,f){this.a=d
this.b=e
this.c=f},
csr:function csr(d,e,f){this.a=d
this.b=e
this.c=f},
csi:function csi(){},
csj:function csj(){},
csk:function csk(){},
csl:function csl(){},
csm:function csm(){},
csn:function csn(){},
csq:function csq(d){this.a=d},
csf:function csf(){},
csp:function csp(){},
cso:function cso(d,e){this.a=d
this.b=e},
csg:function csg(d,e,f){this.a=d
this.b=e
this.c=f},
csh:function csh(d,e){this.a=d
this.b=e}},D
J=c[1]
A=c[0]
C=c[2]
E=c[19]
B=a.updateHolder(c[14],B)
D=c[27]
B.vw.prototype={
I(){return this.c.$0()},
gad(){return this.a}}
B.H7.prototype={
a7(){return new B.aK7(A.a(["All","Students","Receipts & Payments","Plans","Sections","Announcements"],y.s))}}
B.aK7.prototype={
zZ(d,e){return this.br5(d,e)},
br5(c5,c6){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4
var $async$zZ=A.j(function(c7,c8){if(c7===1){t.push(c8)
x=u}for(;;)switch(x){case 0:c0=s.gV().G($.aH(),y.T)
c1=c0==null?"":c0
if(J.ad(c1)===0){x=1
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
p=A.d6(a5.b(c6.h(0,"originalData"))?A.d6(a5.a(c6.h(0,"originalData")),a6,a7):A.d6(c6,a6,a7),a6,a7)
J.hr(p,"deletedAt")
J.hr(p,"type")
J.hr(p,"libraryId")
J.hr(p,"displayName")
J.hr(p,"expiresAt")
J.hr(p,"deletedBy")
J.hr(p,"originalData")
J.hr(p,"linkedPayments")
if(J.p(r,"plan"))J.T(p,"deletedAt",null)
x=J.p(r,"student")&&J.k(p,"seatId")!=null?3:4
break
case 3:a8=A.b2(J.k(p,"seatId"))
a9=$.h
b0=(a9==null?$.h=$.M():a9).D("[DEFAULT]")
A.G(b0,$.a9(),!0)
x=5
return A.d(A.a3(new A.K(b0)).n("libraries").u(c1).n("students").bo(0,"seatId",a8).bo(0,"membershipStatus","active").a_(),$async$zZ)
case 5:b1=c8
x=b1.ga2().length!==0?6:7
break
case 6:b2=C.h.ga5(b1.ga2()).I().h(0,"name")
if(b2==null)b2="another student"
a9=s.c
if(a9==null){x=1
break}x=8
return A.d(A.bQ(null,null,!0,null,new B.cs8(a8,b2),a9,null,!0,!0,y.y),$async$zZ)
case 8:if(c8!==!0){x=1
break}J.T(p,"seatId",null)
case 7:case 4:u=10
a9=$.h
b0=(a9==null?$.h=$.M():a9).D("[DEFAULT]")
a9=$.a9()
A.G(b0,a9,!0)
b3=A.a3(new A.K(b0))
o=A.ft(b3,b3.gcH().e5())
b3=$.h
b0=(b3==null?$.h=$.M():b3).D("[DEFAULT]")
A.G(b0,a9,!0)
n=A.a3(new A.K(b0)).n("libraries").u(c1).n(q).u(c5)
b3=$.h
b0=(b3==null?$.h=$.M():b3).D("[DEFAULT]")
A.G(b0,a9,!0)
m=A.a3(new A.K(b0)).n("libraries").u(c1).n("recycle_bin").u(c5)
b3=y.P
o.iJ(n,p,A.dz(!0),b3)
o.b.jr(m.gbT())
if(J.p(r,"receipt")){b4=A.bf(c6.h(0,"amount"))
b5=b4==null?null:b4
l=b5==null?0:b5
b4=J.k(p,"status")
k=J.L(b4==null?"active":b4).toLowerCase()
if(l>0&&!J.p(k,"voided")){b4=$.h
b0=(b4==null?$.h=$.M():b4).D("[DEFAULT]")
A.G(b0,a9,!0)
A.awN(o,A.a3(new A.K(b0)),c1,l,1,J.k(p,"createdAt"))}j=c6.h(0,"linkedPayments")
if(y.j.b(j))for(a9=J.bD(j);a9.E();){i=a9.gY()
if(!a5.b(i))continue
h=A.d6(i,a6,a7)
b4=J.k(h,"id")
g=J.L(b4==null?"":b4)
b4=J.ad(g)
b6=$.h
if(b4!==0){b0=(b6==null?$.h=$.M():b6).D("[DEFAULT]")
A.G(b0,$.a9(),!0)
b7=A.a3(new A.K(b0)).n("libraries").u(c1).n("payments").u(g)}else{b0=(b6==null?$.h=$.M():b6).D("[DEFAULT]")
A.G(b0,$.a9(),!0)
b7=A.a3(new A.K(b0)).n("libraries").u(c1).n("payments").fP()}f=b7
J.T(h,"id",C.h.gak(f.a.b.a))
J.T(h,"aggregateSyncedByClient",!0)
o.iJ(f,h,A.dz(!0),b3)}}x=J.p(r,"payment")?13:14
break
case 13:a5=A.bf(c6.h(0,"amount"))
l=a5==null?null:a5
e=l==null?0:l
d=A.D(c6.h(0,"studentId"))
a5=A.D(c6.h(0,"status"))
if(a5==null)a5=""
a0=a5.toLowerCase()
if(e>0&&!J.p(a0,"voided")&&!J.p(a0,"cancelled")&&!J.p(a0,"refunded")){J.T(p,"aggregateSyncedByClient",!0)
o.iJ(n,p,A.dz(!0),b3)
a5=$.h
b0=(a5==null?$.h=$.M():a5).D("[DEFAULT]")
A.G(b0,$.a9(),!0)
a5=A.a3(new A.K(b0))
a7=J.k(p,"date")
if(a7==null)a7=J.k(p,"createdAt")
A.awN(o,a5,c1,e,1,a7)}x=e>0&&d!=null&&d.length!==0&&!J.p(a0,"voided")&&!J.p(a0,"refunded")?15:16
break
case 15:u=18
a5=$.h
b0=(a5==null?$.h=$.M():a5).D("[DEFAULT]")
A.G(b0,$.a9(),!0)
x=21
return A.d(A.a3(new A.K(b0)).n("libraries").u(c1).n("students").u(d).a_(),$async$zZ)
case 21:a1=c8
if(a1.gb2()){a5=a1.I()
a5=A.bf(a5==null?null:a5.h(0,"pendingDueBalance"))
b8=a5==null?null:a5
a2=b8==null?0:b8
a3=C.l.ab(a2-e,0,1/0)
a5=a1.gc4()
a7=$.b0().al()
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
return A.d(o.b.dI(),$async$zZ)
case 22:u=24
a5=$.h
b0=(a5==null?$.h=$.M():a5).D("[DEFAULT]")
A.G(b0,$.a9(),!0)
x=27
return A.d(A.a3(new A.K(b0)).n("recycle_bin").u(c5).a.aN(),$async$zZ)
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
if(a5!=null)a5.M(y.q).f.a3(A.aW(null,null,null,C.W,C.ac,C.z,null,A.c("Restored "+r.toUpperCase()+" successfully! \u2713",null,null,null,null,null,null,null,null),null,C.L,null,null,null,null,null,null,null,null,null,null))
u=2
x=12
break
case 10:u=9
c4=t.pop()
a4=A.aa(c4)
a5=s.c
if(a5!=null)A.cu(a5,a4,"student")
x=12
break
case 9:x=2
break
case 12:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$zZ,w)},
azt(d,e,f,g){var x=null
return A.bQ(x,x,!0,x,new B.cse(new A.aA(C.as,$.ax()),f,g,e),d,x,!0,!0,y.y)},
Hh(d){return this.b6V(d)},
b6V(d){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i
var $async$Hh=A.j(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:l=s.gV().G($.aH(),y.T)
k=l==null?"":l
if(J.ad(k)===0){x=1
break}p=s.c
p.toString
x=3
return A.d(s.azt(p,"This will permanently destroy this record. This action cannot be undone.","DELETE","Delete Forever?"),$async$Hh)
case 3:if(f!==!0){x=1
break}u=5
p=$.h
o=(p==null?$.h=$.M():p).D("[DEFAULT]")
p=$.a9()
A.G(o,p,!0)
n=A.a3(new A.K(o))
r=A.ft(n,n.gcH().e5())
n=$.h
o=(n==null?$.h=$.M():n).D("[DEFAULT]")
A.G(o,p,!0)
n=A.a3(new A.K(o)).n("libraries").u(k).n("recycle_bin").u(d)
r.b.jr(n.gbT())
n=$.h
o=(n==null?$.h=$.M():n).D("[DEFAULT]")
A.G(o,p,!0)
n=A.a3(new A.K(o)).n("libraries").u(k).n("plans").u(d)
r.b.jr(n.gbT())
x=8
return A.d(r.b.dI(),$async$Hh)
case 8:u=10
n=$.h
o=(n==null?$.h=$.M():n).D("[DEFAULT]")
A.G(o,p,!0)
x=13
return A.d(A.a3(new A.K(o)).n("recycle_bin").u(d).a.aN(),$async$Hh)
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
if(p!=null)p.M(y.q).f.a3(D.cg3)
u=2
x=7
break
case 5:u=4
i=t.pop()
q=A.aa(i)
p=s.c
if(p!=null)A.R7(p,q)
x=7
break
case 4:x=2
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$Hh,w)},
wW(d){return this.b8s(d)},
b8s(a2){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1
var $async$wW=A.j(function(a3,a4){if(a3===1){t.push(a4)
x=u}for(;;)switch(x){case 0:d=s.c
d.toString
x=3
return A.d(s.azt(d,"This will permanently destroy ALL items in the recycle bin. No data can be restored afterwards.","EMPTY","Empty Recycle Bin?"),$async$wW)
case 3:if(a4!==!0){x=1
break}u=5
d=$.h
i=(d==null?$.h=$.M():d).D("[DEFAULT]")
d=$.a9()
A.G(i,d,!0)
x=8
return A.d(A.a3(new A.K(i)).n("libraries").u(a2).n("recycle_bin").a_(),$async$wW)
case 8:r=a4
h=$.h
i=(h==null?$.h=$.M():h).D("[DEFAULT]")
A.G(i,d,!0)
d=A.a3(new A.K(i))
q=A.ft(d,d.gcH().e5())
for(d=r.ga2(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a_)(d),++g){p=d[g]
f=p.gc4()
q.b.jr(f.gbT())}d=$.h
i=(d==null?$.h=$.M():d).D("[DEFAULT]")
A.G(i,$.a9(),!0)
x=9
return A.d(A.a3(new A.K(i)).n("libraries").u(a2).n("plans").a_(),$async$wW)
case 9:o=a4
for(d=o.ga2(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a_)(d),++g){n=d[g]
if(n.I().h(0,"deletedAt")!=null){f=n.gc4()
q.b.jr(f.gbT())}}x=10
return A.d(q.b.dI(),$async$wW)
case 10:u=12
d=$.h
i=(d==null?$.h=$.M():d).D("[DEFAULT]")
d=$.a9()
A.G(i,d,!0)
x=15
return A.d(A.a3(new A.K(i)).n("recycle_bin").bo(0,"libraryId",a2).a_(),$async$wW)
case 15:m=a4
h=$.h
i=(h==null?$.h=$.M():h).D("[DEFAULT]")
A.G(i,d,!0)
d=A.a3(new A.K(i))
l=A.ft(d,d.gcH().e5())
for(d=m.ga2(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a_)(d),++g){k=d[g]
f=k.gc4()
l.b.jr(f.gbT())}x=16
return A.d(l.b.dI(),$async$wW)
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
if(d!=null)d.M(y.q).f.a3(D.cgI)
u=2
x=7
break
case 5:u=4
a1=t.pop()
j=A.aa(a1)
d=s.c
if(d!=null)A.cu(d,j,"student")
x=7
break
case 4:x=2
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$wW,w)},
P(d){var x,w,v,u,t,s,r,q,p=this,o=null,n="[DEFAULT]",m="libraries",l="recycle_bin",k=p.gV().a4($.aH(),y.T)
if(k==null)k=""
if(k.length===0)return A.h3(!1,A.ce(A.ct(o,o,o,!0,!0,o,o,1,o,o,o,!1,o,!1,o,o,A.aK(o,o,o,C.bI,o,o,new B.csu(d),o,o,o,"Back",o),o,!0,o,o,o,o,o,D.V7,o,o,o,1,o,!0),o,E.Rz,o,!1,o,o),new B.csv(d),y.K)
x=$.h
w=(x==null?$.h=$.M():x).D(n)
x=$.a9()
A.G(w,x,!0)
v=A.a3(new A.K(w)).n(m).u(k).n(l).cQ()
u=$.h
w=(u==null?$.h=$.M():u).D(n)
A.G(w,x,!0)
t=A.a3(new A.K(w)).n(m).u(k).n("plans").cQ()
u=$.h
w=(u==null?$.h=$.M():u).D(n)
A.G(w,x,!0)
s=A.a3(new A.K(w)).n(l).bo(0,"libraryId",k).cQ().EV(new B.csw())
x=A.aK(o,o,o,C.bI,o,o,new B.csx(d),o,o,o,"Back",o)
u=A.a([A.ex(D.aUD,D.cNg,new B.csy(p,k),o)],y.p)
r=p.x
q=A.ab(r).i("X<1,jn>")
r=A.Z(new A.X(r,new B.csz(),q),q.i("aJ.E"))
return A.h3(!1,A.apM(A.ce(A.ct(u,o,o,!0,!0,o,A.x9(o,o,o,2,!0,o,o,o,new B.csA(p),o,C.kW,r,o,o),1,o,o,o,!1,o,!1,o,o,x,o,!0,o,o,o,o,o,D.V7,o,o,o,1,o,!0),o,A.hx(new B.csB(p,t,s),o,v,y.C),o,!1,o,o),6),new B.csC(d),y.K)}}
var z=a.updateTypes(["a8(vw)","F(vw,vw)"])
B.cs8.prototype={
$1(d){var x=null,w=A.c('Desk "'+this.a+'" is currently assigned to active student "'+A.r(this.b)+'".\n\nTo prevent a double-booking collision, would you like to restore this student with an unassigned seat status?',x,x,x,x,x,x,x,x)
return A.ci(A.a([A.bp(C.b2,x,x,x,new B.cs6(d),x,x),A.cF(D.cut,new B.cs7(d),x)],y.p),x,x,w,x,x,x,D.caZ,x)},
$S:6}
B.cs6.prototype={
$0(){A.a7(this.a,!1).S(!1)
return null},
$S:0}
B.cs7.prototype={
$0(){A.a7(this.a,!1).S(!0)
return null},
$S:0}
B.cse.prototype={
$1(d){var x=this
return new A.fO(new B.csd(x.a,x.b,x.c,x.d,d),null)},
$S:20}
B.csd.prototype={
$2(d,e){var x,w,v,u=this,t=null,s=u.a,r=C.d.q(s.a.a),q=u.b,p=A.c(u.c,t,t,t,t,C.bJ,t,t,t),o=y.p
s=A.z(A.a([A.c(u.d,t,t,t,t,t,t,t,t),C.P,A.c('To confirm, please type "'+q+'" below:',t,t,t,t,A.A(t,t,A.H(d).ax.fy,t,t,t,t,t,t,t,t,t,t,t,C.a1,t,t,!0,t,t,t,t,t,t,t,t),t,t,t),C.N,A.bU(t,C.ak,!0,t,!0,C.z,t,A.bW(),s,t,t,t,t,t,2,A.cd(t,C.a_,t,C.cv,t,t,t,t,!0,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,q,t,t,t,t,t,t,t,t,t,!0,!0,!1,t,t,t,t,t,t,t,t,t,t,t,t,t,t),C.J,!0,t,!0,t,!1,t,C.aB,t,t,t,t,t,t,t,t,1,t,t,!1,"\u2022",t,new B.csa(e),t,t,t,!1,t,t,!1,t,!0,t,C.ag,t,t,t,t,t,t,t,t,t,t,t,t,!0,C.Q,t,C.R,t,t,t,t)],o),C.x,t,C.f,C.C,0,C.o)
x=u.e
w=A.bp(C.b2,t,t,t,new B.csb(x),t,t)
v=A.b6(C.a7,t,t,t,t,t,t,t,t)
return A.ci(A.a([w,A.cF(D.cMO,r.toUpperCase()===q?new B.csc(x):t,v)],o),t,t,s,t,D.aKQ,t,p,t)},
$S:39}
B.csa.prototype={
$1(d){return this.a.$1(new B.cs9())},
$S:8}
B.cs9.prototype={
$0(){},
$S:0}
B.csb.prototype={
$0(){A.a7(this.a,!1).S(!1)
return null},
$S:0}
B.csc.prototype={
$0(){A.a7(this.a,!1).S(!0)
return null},
$S:0}
B.csv.prototype={
$2(d,e){var x,w
if(d)return
x=this.a
w=A.af(x).c
w===$&&A.b()
if(w.cs())A.af(x).S(null)
else A.af(x).b4("/admin/home",null)},
$S:27}
B.csu.prototype={
$0(){var x=this.a,w=A.af(x).c
w===$&&A.b()
return w.cs()?A.af(x).S(null):A.af(x).b4("/admin/home",null)},
$S:0}
B.csw.prototype={
$1(d){A.f3().$1("Global bin query note: "+A.r(d))},
$S:5}
B.csC.prototype={
$2(d,e){var x,w
if(d)return
x=this.a
w=A.af(x).c
w===$&&A.b()
if(w.cs())A.af(x).S(null)
else A.af(x).b4("/admin/home",null)},
$S:27}
B.csx.prototype={
$0(){var x=this.a,w=A.af(x).c
w===$&&A.b()
return w.cs()?A.af(x).S(null):A.af(x).b4("/admin/home",null)},
$S:0}
B.csy.prototype={
$0(){return this.a.wW(this.b)},
$S:0}
B.csA.prototype={
$1(d){var x=this.a
x.v(new B.cst(x,d))},
$S:29}
B.cst.prototype={
$0(){var x=this.a
x.w=x.x[this.b]},
$S:0}
B.csz.prototype={
$1(d){return A.p9(null,null,d)},
$S:1847}
B.csB.prototype={
$2(d,e){var x=null,w=e.c
if(w!=null)return A.aE(new A.U(C.bH,A.z(A.a([D.aSj,C.F,A.c(A.jt(w,x),x,x,x,x,C.Eo,C.ah,x,x)],y.p),C.k,x,C.f,C.C,0,C.o),x),x,x)
return A.hx(new B.css(this.a,this.c,e),x,this.b,y.C)},
$S:89}
B.css.prototype={
$2(d,e){return A.hx(new B.csr(this.a,this.c,e),null,this.b,y.C)},
$S:316}
B.csr.prototype={
$2(d,a0){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=null,i="originalData",h="type",g="name",f={},e=this.b
if(e.a===C.fa&&e.b==null)return C.ba
x=y.N
w=A.I(x,y.v)
e=e.b
if(e!=null)for(e=e.ga2(),v=e.length,u=y.f,t=y.z,s=0;s<e.length;e.length===v||(0,A.a_)(e),++s){r=e[s]
q=r.I()
if(u.b(q.h(0,i))){p=u.a(q.h(0,i)).fN(0,x,t)
o=A.td(j,j,x,t)
o.B(0,p)
o.B(0,q)
n=o}else n=q
p=n.h(0,h)
p=J.L(p==null?"student":p)
w.j(0,r.gad(),new B.vw(r.gad(),p.toLowerCase(),n))}e=this.c.b
if(e!=null)for(e=e.ga2(),v=e.length,u=y.z,s=0;s<e.length;e.length===v||(0,A.a_)(e),++s){r=e[s]
m=r.I()
if(m.h(0,"deletedAt")!=null&&!w.ar(r.gad())){t=A.td(j,j,x,u)
t.B(0,m)
t.j(0,"id",r.gad())
t.j(0,h,"plan")
p=m.h(0,g)
t.j(0,g,p==null?"Plan":p)
p=m.h(0,g)
t.j(0,"displayName",p==null?"Plan":p)
w.j(0,r.gad(),new B.vw(r.gad(),"plan",t))}}e=a0.b
if(e!=null)for(e=e.ga2(),v=e.length,u=y.f,t=y.z,s=0;s<e.length;e.length===v||(0,A.a_)(e),++s){r=e[s]
if(!w.ar(r.gad())){q=r.I()
if(u.b(q.h(0,i))){p=u.a(q.h(0,i)).fN(0,x,t)
o=A.td(j,j,x,t)
o.B(0,p)
o.B(0,q)
n=o}else n=q
p=n.h(0,h)
p=J.L(p==null?"student":p)
w.j(0,r.gad(),new B.vw(r.gad(),p.toLowerCase(),n))}}e=w.$ti.i("cP<2>")
l=A.Z(new A.cP(w,e),e.i("P.E"))
C.h.cK(l,new B.csi())
f.a=null
e=this.a
x=e.w
if(x==="Students"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.csj(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Receipts & Payments"||x==="Receipts"||x==="Payments"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.csk(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Plans"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.csl(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Sections"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.csm(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Announcements"){x=A.ab(l).i("au<1>")
k=A.Z(new A.au(l,new B.csn(),x),x.i("P.E"))
f.a=k
x=k}else{f.a=l
x=l}x=x.length
if(x===0){e=e.w
return new A.ye(C.lC,"No deleted "+(e==="All"?"items":e.toLowerCase())+" found!","Deleted items appear here for 30 days and can be restored anytime.",j,j,j)}return A.kh(A.lo(j,new B.cso(f,e),x,C.hR,j,new B.csp(),!1),new B.csq(e))},
$S:89}
B.csi.prototype={
$2(d,e){var x,w,v,u="deletedAt",t=d.c.h(0,u),s=e.c.h(0,u)
if(t instanceof A.dX)x=A.eF(t.gbe())
else x=typeof t=="string"?A.dB(t):null
if(s instanceof A.dX)w=A.eF(s.gbe())
else w=typeof s=="string"?A.dB(s):null
v=x==null
if(v&&w==null)return 0
if(v)return 1
if(w==null)return-1
return w.b8(0,x)},
$S:z+1}
B.csj.prototype={
$1(d){return d.b==="student"},
$S:z+0}
B.csk.prototype={
$1(d){var x=d.b
return x==="receipt"||x==="payment"},
$S:z+0}
B.csl.prototype={
$1(d){return d.b==="plan"},
$S:z+0}
B.csm.prototype={
$1(d){return d.b==="section"},
$S:z+0}
B.csn.prototype={
$1(d){return d.b==="announcement"},
$S:z+0}
B.csq.prototype={
$0(){var x=0,w=A.o(y.H),v=this
var $async$$0=A.j(function(d,e){if(d===1)return A.l(e,w)
for(;;)switch(x){case 0:v.a.v(new B.csf())
x=2
return A.d(A.hf(C.pg,null,y.z),$async$$0)
case 2:return A.m(null,w)}})
return A.n($async$$0,w)},
$S:1}
B.csf.prototype={
$0(){},
$S:0}
B.csp.prototype={
$2(d,e){return C.bX},
$S:84}
B.cso.prototype={
$2(a4,a5){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=null,e="displayName",d="paymentMethod",a0="name",a1=this.a.a[a5],a2=a1.c,a3=a1.b
switch(a3){case"receipt":x=a2.h(0,e)
if(x==null){w=a2.h(0,"receiptNumber")
x="Receipt #"+A.r(w==null?a1.a:w)}w=A.bf(a2.h(0,"amount"))
w=w==null?f:C.l.R(w,0)
w=A.r(w==null?0:w)
v=a2.h(0,d)
u="Amount: \u20b9"+w+" \u2022 Paid via: "+A.r(v==null?"Cash":v)
t=C.de
s=C.bj
break
case"payment":x=a2.h(0,e)
if(x==null){w=A.bf(a2.h(0,"amount"))
w=w==null?f:C.l.R(w,0)
x="Payment: \u20b9"+A.r(w==null?0:w)}w=a2.h(0,d)
if(w==null)w=a2.h(0,"method")
u="Method: "+A.r(w==null?"Cash":w)
t=C.is
s=C.W
break
case"plan":x=a2.h(0,a0)
if(x==null)x="Plan"
w=A.r(a2.h(0,"price"))
v=A.r(a2.h(0,"duration"))
r=a2.h(0,"durationUnit")
u="Fee: \u20b9"+w+" \u2022 "+v+" "+A.r(r==null?"months":r)
t=C.rW
s=C.eH
break
case"section":x=a2.h(0,a0)
if(x==null)x="Section / Hall"
w=a2.h(0,"totalSeats")
u=A.r(w==null?"Configured":w)+" seats"
t=C.pP
s=C.c9
break
case"announcement":x=a2.h(0,"title")
if(x==null)x="Announcement"
u=a2.h(0,"message")
if(u==null)u=""
t=C.hy
s=C.eI
break
case"student":default:x=a2.h(0,a0)
if(x==null)x="Student"
q=a2.h(0,"phone")
if(q==null)q=""
p=a2.h(0,"seatId")
if(p==null)p=""
w=J.eE(q)?"Phone: "+A.r(q):""
u=w+(J.eE(p)?" \u2022 Seat: "+A.r(p):"")
t=C.fl
s=C.bt
break}o=a2.h(0,"deletedAt")
n=""
m=30
if(o!=null){l=o instanceof A.dX?A.eF(o.gbe()):f
if(typeof o=="string")l=A.dB(o)
if(l!=null){n=A.aL("dd MMM yyyy",f).a9(l)
m=C.j.ab(30-C.j.af(new A.ac(Date.now(),0,!1).ca(l).a,864e8),0,30)}}w=A.cU(s.m(0.12),f,A.Y(t,s,f,f,22),f,f,f)
v=A.c(x,f,f,f,f,C.dI,f,f,f)
r=y.p
k=A.a([],r)
if(u.length!==0)k.push(A.c(u,f,f,f,f,C.xO,f,f,f))
k.push(C.db)
j=s.m(0.15)
i=A.i(4)
i=A.a([A.w(f,A.c(a3.toUpperCase(),f,f,f,f,A.A(f,f,s,f,f,f,f,f,f,f,f,10,f,f,C.w,f,f,!0,f,f,f,f,f,f,f,f),f,f,f),C.n,f,f,new A.x(j,f,f,i,f,f,C.u),f,f,f,f,C.bK,f,f,f),C.D],r)
if(n.length!==0)i.push(A.c("Deleted: "+n,f,f,f,f,C.kY,f,f,f))
i.push(C.c6)
j=m<=5
h=j?C.nv:C.fh
g=A.i(4)
i.push(A.w(f,A.c(""+m+" days left",f,f,f,f,A.A(f,f,j?C.eD:C.bl,f,f,f,f,f,f,f,f,10,f,f,C.w,f,f,!0,f,f,f,f,f,f,f,f),f,f,f),C.n,f,f,new A.x(h,f,f,g,f,f,C.u),f,f,f,f,C.bK,f,f,f))
k.push(A.u(i,C.k,C.f,C.i,0,f,f))
i=this.b
return A.c_(!1,f,f,f,!0,f,f,f,!0,f,f,w,f,f,f,f,f,!1,f,f,f,f,f,A.z(k,C.x,f,C.f,C.i,0,C.o),f,f,v,f,A.u(A.a([A.aK(f,f,f,C.Ym,f,f,new B.csg(i,a1,a2),f,f,f,"Restore "+a3,f),A.aK(f,f,f,C.Y4,f,f,new B.csh(i,a1),f,f,f,"Delete Forever",f)],r),C.k,C.f,C.C,0,f,f),f)},
$S:80}
B.csg.prototype={
$0(){return this.a.zZ(this.b.a,this.c)},
$S:0}
B.csh.prototype={
$0(){return this.a.Hh(this.b.a)},
$S:0};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.vw,A.W)
x(B.H7,A.oB)
x(B.aK7,A.nP)
w(A.ma,[B.cs8,B.cse,B.csa,B.csw,B.csA,B.csz,B.csj,B.csk,B.csl,B.csm,B.csn])
w(A.oz,[B.cs6,B.cs7,B.cs9,B.csb,B.csc,B.csu,B.csx,B.csy,B.cst,B.csq,B.csf,B.csg,B.csh])
w(A.oA,[B.csd,B.csv,B.csC,B.csB,B.css,B.csr,B.csi,B.csp,B.cso])})()
A.vD(b.typeUniverse,JSON.parse('{"H7":{"ak":[],"v":[]},"aK7":{"ap":["H7"]}}'))
var y=(function rtii(){var x=A.az
return{s:x("a2<e>"),p:x("a2<v>"),j:x("Q<@>"),P:x("ae<e,@>"),f:x("ae<@,@>"),K:x("W"),C:x("dk<ae<e,@>>"),N:x("e"),v:x("vw"),q:x("qh"),y:x("a8"),z:x("@"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.cxq=new A.f("Recycle Bin",null,null,null,null,null,null,null,null,null,null)
D.V7=new A.lk(C.cp,C.a6,D.cxq,null)
D.aKQ=new A.y(C.d4,36,C.a7,null,null)
D.aSj=new A.y(C.ke,48,C.a7,null,null)
D.aUD=new A.y(C.Ai,null,C.a7,null,null)
D.aRi=new A.y(C.d4,null,C.bj,null,null)
D.cBG=new A.f("Seat Already Occupied",null,null,null,null,null,null,null,null,null,null)
D.bNI=x([D.aRi,C.D,D.cBG],y.p)
D.caZ=new A.c1(C.ab,C.f,C.i,C.k,null,C.o,null,0,D.bNI,null)
D.cIj=new A.f("Permanently deleted.",null,null,null,null,null,null,null,null,null,null)
D.cg3=new A.bJ(D.cIj,null,null,null,null,null,null,null,null,null,null,null,null,C.L,!1,null,null,null,C.z,null)
D.ctr=new A.f("Recycle bin emptied.",null,null,null,null,null,null,null,null,null,null)
D.cgI=new A.bJ(D.ctr,null,null,null,null,null,null,null,null,null,null,null,null,C.L,!1,null,null,null,C.z,null)
D.cut=new A.f("Restore Without Seat",null,null,null,null,null,null,null,null,null,null)
D.cMO=new A.f("Delete Permanently",null,null,null,null,null,null,null,null,null,null)
D.cNg=new A.f("Empty All",null,C.jQ,null,null,null,null,null,null,null,null)})()};
(a=>{a["2+oVQ34SB43xZW8WCH1jRtXSe8E="]=a.current})($__dart_deferred_initializers__);