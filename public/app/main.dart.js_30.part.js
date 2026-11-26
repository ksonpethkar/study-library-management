((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
dKv(){return new B.GF(null)},
vd:function vd(d,e,f){this.a=d
this.b=e
this.c=f},
GF:function GF(d){this.a=d},
aJh:function aJh(d){var _=this
_.w="All"
_.x=d
_.d=$
_.c=_.a=null},
cq3:function cq3(d,e){this.a=d
this.b=e},
cq1:function cq1(d){this.a=d},
cq2:function cq2(d){this.a=d},
cq9:function cq9(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
cq8:function cq8(d,e,f,g,h){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h},
cq5:function cq5(d){this.a=d},
cq4:function cq4(){},
cq6:function cq6(d){this.a=d},
cq7:function cq7(d){this.a=d},
cqq:function cqq(d){this.a=d},
cqp:function cqp(d){this.a=d},
cqr:function cqr(){},
cqx:function cqx(d){this.a=d},
cqs:function cqs(d){this.a=d},
cqt:function cqt(d,e){this.a=d
this.b=e},
cqv:function cqv(d){this.a=d},
cqo:function cqo(d,e){this.a=d
this.b=e},
cqu:function cqu(){},
cqw:function cqw(d,e,f){this.a=d
this.b=e
this.c=f},
cqn:function cqn(d,e,f){this.a=d
this.b=e
this.c=f},
cqm:function cqm(d,e,f){this.a=d
this.b=e
this.c=f},
cqd:function cqd(){},
cqe:function cqe(){},
cqf:function cqf(){},
cqg:function cqg(){},
cqh:function cqh(){},
cqi:function cqi(){},
cql:function cql(d){this.a=d},
cqa:function cqa(){},
cqk:function cqk(){},
cqj:function cqj(d,e){this.a=d
this.b=e},
cqb:function cqb(d,e,f){this.a=d
this.b=e
this.c=f},
cqc:function cqc(d,e){this.a=d
this.b=e}},D
J=c[1]
A=c[0]
C=c[2]
E=c[19]
B=a.updateHolder(c[14],B)
D=c[28]
B.vd.prototype={
I(){return this.c.$0()},
gac(){return this.a}}
B.GF.prototype={
a7(){return new B.aJh(A.a(["All","Students","Receipts & Payments","Plans","Sections","Announcements"],y.s))}}
B.aJh.prototype={
zO(d,e){return this.bpO(d,e)},
bpO(c5,c6){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4
var $async$zO=A.k(function(c7,c8){if(c7===1){t.push(c8)
x=u}for(;;)switch(x){case 0:c0=s.gV().G($.aG(),y.T)
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
p=A.d3(a5.b(c6.h(0,"originalData"))?A.d3(a5.a(c6.h(0,"originalData")),a6,a7):A.d3(c6,a6,a7),a6,a7)
J.hm(p,"deletedAt")
J.hm(p,"type")
J.hm(p,"libraryId")
J.hm(p,"displayName")
J.hm(p,"expiresAt")
J.hm(p,"deletedBy")
J.hm(p,"originalData")
J.hm(p,"linkedPayments")
if(J.p(r,"plan"))J.T(p,"deletedAt",null)
x=J.p(r,"student")&&J.j(p,"seatId")!=null?3:4
break
case 3:a8=A.b0(J.j(p,"seatId"))
a9=$.h
b0=(a9==null?$.h=$.L():a9).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
x=5
return A.d(A.a3(new A.J(b0)).m("libraries").u(c1).m("students").bk(0,"seatId",a8).bk(0,"membershipStatus","active").a_(),$async$zO)
case 5:b1=c8
x=b1.ga2().length!==0?6:7
break
case 6:b2=C.h.ga5(b1.ga2()).I().h(0,"name")
if(b2==null)b2="another student"
a9=s.c
if(a9==null){x=1
break}x=8
return A.d(A.bQ(null,null,!0,null,new B.cq3(a8,b2),a9,null,!0,!0,y.y),$async$zO)
case 8:if(c8!==!0){x=1
break}J.T(p,"seatId",null)
case 7:case 4:u=10
a9=$.h
b0=(a9==null?$.h=$.L():a9).D("[DEFAULT]")
a9=$.a9()
A.H(b0,a9,!0)
b3=A.a3(new A.J(b0))
o=A.fp(b3,b3.gcF().e2())
b3=$.h
b0=(b3==null?$.h=$.L():b3).D("[DEFAULT]")
A.H(b0,a9,!0)
n=A.a3(new A.J(b0)).m("libraries").u(c1).m(q).u(c5)
b3=$.h
b0=(b3==null?$.h=$.L():b3).D("[DEFAULT]")
A.H(b0,a9,!0)
m=A.a3(new A.J(b0)).m("libraries").u(c1).m("recycle_bin").u(c5)
b3=y.P
o.iG(n,p,A.dF(!0),b3)
o.b.jm(m.gbS())
if(J.p(r,"receipt")){b4=A.be(c6.h(0,"amount"))
b5=b4==null?null:b4
l=b5==null?0:b5
b4=J.j(p,"status")
k=J.K(b4==null?"active":b4).toLowerCase()
if(l>0&&!J.p(k,"voided")){b4=$.h
b0=(b4==null?$.h=$.L():b4).D("[DEFAULT]")
A.H(b0,a9,!0)
A.aw_(o,A.a3(new A.J(b0)),c1,l,1,J.j(p,"createdAt"))}j=c6.h(0,"linkedPayments")
if(y.j.b(j))for(a9=J.bD(j);a9.E();){i=a9.gY()
if(!a5.b(i))continue
h=A.d3(i,a6,a7)
b4=J.j(h,"id")
g=J.K(b4==null?"":b4)
b4=J.ac(g)
b6=$.h
if(b4!==0){b0=(b6==null?$.h=$.L():b6).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
b7=A.a3(new A.J(b0)).m("libraries").u(c1).m("payments").u(g)}else{b0=(b6==null?$.h=$.L():b6).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
b7=A.a3(new A.J(b0)).m("libraries").u(c1).m("payments").fL()}f=b7
J.T(h,"id",C.h.gaj(f.a.b.a))
J.T(h,"aggregateSyncedByClient",!0)
o.iG(f,h,A.dF(!0),b3)}}x=J.p(r,"payment")?13:14
break
case 13:a5=A.be(c6.h(0,"amount"))
l=a5==null?null:a5
e=l==null?0:l
d=A.C(c6.h(0,"studentId"))
a5=A.C(c6.h(0,"status"))
if(a5==null)a5=""
a0=a5.toLowerCase()
if(e>0&&!J.p(a0,"voided")&&!J.p(a0,"cancelled")&&!J.p(a0,"refunded")){J.T(p,"aggregateSyncedByClient",!0)
o.iG(n,p,A.dF(!0),b3)
a5=$.h
b0=(a5==null?$.h=$.L():a5).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
a5=A.a3(new A.J(b0))
a7=J.j(p,"date")
if(a7==null)a7=J.j(p,"createdAt")
A.aw_(o,a5,c1,e,1,a7)}x=e>0&&d!=null&&d.length!==0&&!J.p(a0,"voided")&&!J.p(a0,"refunded")?15:16
break
case 15:u=18
a5=$.h
b0=(a5==null?$.h=$.L():a5).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
x=21
return A.d(A.a3(new A.J(b0)).m("libraries").u(c1).m("students").u(d).a_(),$async$zO)
case 21:a1=c8
if(a1.gb1()){a5=a1.I()
a5=A.be(a5==null?null:a5.h(0,"pendingDueBalance"))
b8=a5==null?null:a5
a2=b8==null?0:b8
a3=C.l.am(a2-e,0,1/0)
a5=a1.gc3()
a7=$.b1().al()
o.e6(a5,A.N(["pendingDueBalance",a3,"updatedAt",new A.ai(a7,a7)],a6,y.K),b3)}u=10
x=20
break
case 18:u=17
c2=t.pop()
x=20
break
case 17:x=10
break
case 20:case 16:case 14:x=22
return A.d(o.b.dH(),$async$zO)
case 22:u=24
a5=$.h
b0=(a5==null?$.h=$.L():a5).D("[DEFAULT]")
A.H(b0,$.a9(),!0)
x=27
return A.d(A.a3(new A.J(b0)).m("recycle_bin").u(c5).a.aO(),$async$zO)
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
if(a5!=null)a5.L(y.q).f.a3(A.aY(null,null,null,C.X,C.ad,C.z,null,A.c("Restored "+r.toUpperCase()+" successfully! \u2713",null,null,null,null,null,null,null,null),null,C.L,null,null,null,null,null,null,null,null,null,null))
u=2
x=12
break
case 10:u=9
c4=t.pop()
a4=A.aa(c4)
a5=s.c
if(a5!=null)A.cr(a5,a4,"student")
x=12
break
case 9:x=2
break
case 12:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$zO,w)},
ayH(d,e,f,g){var x=null
return A.bQ(x,x,!0,x,new B.cq9(new A.aA(C.at,$.ax()),f,g,e),d,x,!0,!0,y.y)},
H_(d){return this.b5S(d)},
b5S(d){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i
var $async$H_=A.k(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:l=s.gV().G($.aG(),y.T)
k=l==null?"":l
if(J.ac(k)===0){x=1
break}p=s.c
p.toString
x=3
return A.d(s.ayH(p,"This will permanently destroy this record. This action cannot be undone.","DELETE","Delete Forever?"),$async$H_)
case 3:if(f!==!0){x=1
break}u=5
p=$.h
o=(p==null?$.h=$.L():p).D("[DEFAULT]")
p=$.a9()
A.H(o,p,!0)
n=A.a3(new A.J(o))
r=A.fp(n,n.gcF().e2())
n=$.h
o=(n==null?$.h=$.L():n).D("[DEFAULT]")
A.H(o,p,!0)
n=A.a3(new A.J(o)).m("libraries").u(k).m("recycle_bin").u(d)
r.b.jm(n.gbS())
n=$.h
o=(n==null?$.h=$.L():n).D("[DEFAULT]")
A.H(o,p,!0)
n=A.a3(new A.J(o)).m("libraries").u(k).m("plans").u(d)
r.b.jm(n.gbS())
x=8
return A.d(r.b.dH(),$async$H_)
case 8:u=10
n=$.h
o=(n==null?$.h=$.L():n).D("[DEFAULT]")
A.H(o,p,!0)
x=13
return A.d(A.a3(new A.J(o)).m("recycle_bin").u(d).a.aO(),$async$H_)
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
if(p!=null)p.L(y.q).f.a3(D.cee)
u=2
x=7
break
case 5:u=4
i=t.pop()
q=A.aa(i)
p=s.c
if(p!=null)A.Qt(p,q)
x=7
break
case 4:x=2
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$H_,w)},
wQ(d){return this.b7o(d)},
b7o(a2){var x=0,w=A.o(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1
var $async$wQ=A.k(function(a3,a4){if(a3===1){t.push(a4)
x=u}for(;;)switch(x){case 0:d=s.c
d.toString
x=3
return A.d(s.ayH(d,"This will permanently destroy ALL items in the recycle bin. No data can be restored afterwards.","EMPTY","Empty Recycle Bin?"),$async$wQ)
case 3:if(a4!==!0){x=1
break}u=5
d=$.h
i=(d==null?$.h=$.L():d).D("[DEFAULT]")
d=$.a9()
A.H(i,d,!0)
x=8
return A.d(A.a3(new A.J(i)).m("libraries").u(a2).m("recycle_bin").a_(),$async$wQ)
case 8:r=a4
h=$.h
i=(h==null?$.h=$.L():h).D("[DEFAULT]")
A.H(i,d,!0)
d=A.a3(new A.J(i))
q=A.fp(d,d.gcF().e2())
for(d=r.ga2(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a_)(d),++g){p=d[g]
f=p.gc3()
q.b.jm(f.gbS())}d=$.h
i=(d==null?$.h=$.L():d).D("[DEFAULT]")
A.H(i,$.a9(),!0)
x=9
return A.d(A.a3(new A.J(i)).m("libraries").u(a2).m("plans").a_(),$async$wQ)
case 9:o=a4
for(d=o.ga2(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a_)(d),++g){n=d[g]
if(n.I().h(0,"deletedAt")!=null){f=n.gc3()
q.b.jm(f.gbS())}}x=10
return A.d(q.b.dH(),$async$wQ)
case 10:u=12
d=$.h
i=(d==null?$.h=$.L():d).D("[DEFAULT]")
d=$.a9()
A.H(i,d,!0)
x=15
return A.d(A.a3(new A.J(i)).m("recycle_bin").bk(0,"libraryId",a2).a_(),$async$wQ)
case 15:m=a4
h=$.h
i=(h==null?$.h=$.L():h).D("[DEFAULT]")
A.H(i,d,!0)
d=A.a3(new A.J(i))
l=A.fp(d,d.gcF().e2())
for(d=m.ga2(),h=d.length,g=0;g<d.length;d.length===h||(0,A.a_)(d),++g){k=d[g]
f=k.gc3()
l.b.jm(f.gbS())}x=16
return A.d(l.b.dH(),$async$wQ)
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
if(d!=null)d.L(y.q).f.a3(D.ceT)
u=2
x=7
break
case 5:u=4
a1=t.pop()
j=A.aa(a1)
d=s.c
if(d!=null)A.cr(d,j,"student")
x=7
break
case 4:x=2
break
case 7:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$wQ,w)},
P(d){var x,w,v,u,t,s,r,q,p=this,o=null,n="[DEFAULT]",m="libraries",l="recycle_bin",k=p.gV().a4($.aG(),y.T)
if(k==null)k=""
if(k.length===0)return A.h_(!1,A.c9(A.cq(o,o,o,!0,!0,o,o,1,o,o,o,!1,o,!1,o,o,A.aK(o,o,o,C.bC,o,o,new B.cqp(d),o,o,o,"Back",o),o,!0,o,o,o,o,o,D.UL,o,o,o,1,o,!0),o,E.Rc,o,!1,o,o),new B.cqq(d),y.K)
x=$.h
w=(x==null?$.h=$.L():x).D(n)
x=$.a9()
A.H(w,x,!0)
v=A.a3(new A.J(w)).m(m).u(k).m(l).cO()
u=$.h
w=(u==null?$.h=$.L():u).D(n)
A.H(w,x,!0)
t=A.a3(new A.J(w)).m(m).u(k).m("plans").cO()
u=$.h
w=(u==null?$.h=$.L():u).D(n)
A.H(w,x,!0)
s=A.a3(new A.J(w)).m(l).bk(0,"libraryId",k).cO().EH(new B.cqr())
x=A.aK(o,o,o,C.bC,o,o,new B.cqs(d),o,o,o,"Back",o)
u=A.a([A.ez(D.aTz,D.cL6,new B.cqt(p,k),o)],y.p)
r=p.x
q=A.ab(r).i("X<1,jb>")
r=A.Y(new A.X(r,new B.cqu(),q),q.i("aJ.E"))
return A.h_(!1,A.aoZ(A.c9(A.cq(u,o,o,!0,!0,o,A.wS(o,o,o,2,!0,o,o,o,new B.cqv(p),o,C.kR,r,o,o),1,o,o,o,!1,o,!1,o,o,x,o,!0,o,o,o,o,o,D.UL,o,o,o,1,o,!0),o,A.hw(new B.cqw(p,t,s),o,v,y.C),o,!1,o,o),6),new B.cqx(d),y.K)}}
var z=a.updateTypes(["a7(vd)","E(vd,vd)"])
B.cq3.prototype={
$1(d){var x=null,w=A.c('Desk "'+this.a+'" is currently assigned to active student "'+A.r(this.b)+'".\n\nTo prevent a double-booking collision, would you like to restore this student with an unassigned seat status?',x,x,x,x,x,x,x,x)
return A.cg(A.a([A.bs(C.b1,x,x,x,new B.cq1(d),x,x),A.cE(D.csx,new B.cq2(d),x)],y.p),x,x,w,x,x,x,D.c9d,x)},
$S:6}
B.cq1.prototype={
$0(){A.a8(this.a,!1).T(!1)
return null},
$S:0}
B.cq2.prototype={
$0(){A.a8(this.a,!1).T(!0)
return null},
$S:0}
B.cq9.prototype={
$1(d){var x=this
return new A.fM(new B.cq8(x.a,x.b,x.c,x.d,d),null)},
$S:22}
B.cq8.prototype={
$2(d,e){var x,w,v,u=this,t=null,s=u.a,r=C.d.q(s.a.a),q=u.b,p=A.c(u.c,t,t,t,t,C.bD,t,t,t),o=y.p
s=A.A(A.a([A.c(u.d,t,t,t,t,t,t,t,t),C.O,A.c('To confirm, please type "'+q+'" below:',t,t,t,t,A.z(t,t,A.G(d).ax.fy,t,t,t,t,t,t,t,t,t,t,t,C.a1,t,t,!0,t,t,t,t,t,t,t,t),t,t,t),C.P,A.bW(t,C.al,!0,t,!0,C.z,t,A.bZ(),s,t,t,t,t,t,2,A.cc(t,C.Z,t,C.cv,t,t,t,t,!0,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,q,t,t,t,t,t,t,t,t,t,!0,!0,!1,t,t,t,t,t,t,t,t,t,t,t,t,t,t),C.J,!0,t,!0,t,!1,t,C.aB,t,t,t,t,t,t,t,t,1,t,t,!1,"\u2022",t,new B.cq5(e),t,t,t,!1,t,t,!1,t,!0,t,C.ai,t,t,t,t,t,t,t,t,t,t,t,t,!0,C.Q,t,C.R,t,t,t,t)],o),C.y,t,C.f,C.C,0,C.o)
x=u.e
w=A.bs(C.b1,t,t,t,new B.cq6(x),t,t)
v=A.b4(C.a7,t,t,t,t,t,t,t,t)
return A.cg(A.a([w,A.cE(D.cKF,r.toUpperCase()===q?new B.cq7(x):t,v)],o),t,t,s,t,D.aJR,t,p,t)},
$S:39}
B.cq5.prototype={
$1(d){return this.a.$1(new B.cq4())},
$S:11}
B.cq4.prototype={
$0(){},
$S:0}
B.cq6.prototype={
$0(){A.a8(this.a,!1).T(!1)
return null},
$S:0}
B.cq7.prototype={
$0(){A.a8(this.a,!1).T(!0)
return null},
$S:0}
B.cqq.prototype={
$2(d,e){var x,w
if(d)return
x=this.a
w=A.ad(x).c
w===$&&A.b()
if(w.cq())A.ad(x).T(null)
else A.ad(x).b4("/admin/home",null)},
$S:27}
B.cqp.prototype={
$0(){var x=this.a,w=A.ad(x).c
w===$&&A.b()
return w.cq()?A.ad(x).T(null):A.ad(x).b4("/admin/home",null)},
$S:0}
B.cqr.prototype={
$1(d){A.f5().$1("Global bin query note: "+A.r(d))},
$S:5}
B.cqx.prototype={
$2(d,e){var x,w
if(d)return
x=this.a
w=A.ad(x).c
w===$&&A.b()
if(w.cq())A.ad(x).T(null)
else A.ad(x).b4("/admin/home",null)},
$S:27}
B.cqs.prototype={
$0(){var x=this.a,w=A.ad(x).c
w===$&&A.b()
return w.cq()?A.ad(x).T(null):A.ad(x).b4("/admin/home",null)},
$S:0}
B.cqt.prototype={
$0(){return this.a.wQ(this.b)},
$S:0}
B.cqv.prototype={
$1(d){var x=this.a
x.v(new B.cqo(x,d))},
$S:29}
B.cqo.prototype={
$0(){var x=this.a
x.w=x.x[this.b]},
$S:0}
B.cqu.prototype={
$1(d){return A.p_(null,null,d)},
$S:1832}
B.cqw.prototype={
$2(d,e){var x=null,w=e.c
if(w!=null)return A.aH(new A.V(C.bH,A.A(A.a([D.aRf,C.G,A.c(A.jh(w,x),x,x,x,x,C.Ef,C.af,x,x)],y.p),C.k,x,C.f,C.C,0,C.o),x),x,x)
return A.hw(new B.cqn(this.a,this.c,e),x,this.b,y.C)},
$S:90}
B.cqn.prototype={
$2(d,e){return A.hw(new B.cqm(this.a,this.c,e),null,this.b,y.C)},
$S:344}
B.cqm.prototype={
$2(d,a0){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=null,i="originalData",h="type",g="name",f={},e=this.b
if(e.a===C.f2&&e.b==null)return C.ba
x=y.N
w=A.I(x,y.v)
e=e.b
if(e!=null)for(e=e.ga2(),v=e.length,u=y.f,t=y.z,s=0;s<e.length;e.length===v||(0,A.a_)(e),++s){r=e[s]
q=r.I()
if(u.b(q.h(0,i))){p=u.a(q.h(0,i)).fJ(0,x,t)
o=A.rY(j,j,x,t)
o.B(0,p)
o.B(0,q)
n=o}else n=q
p=n.h(0,h)
p=J.K(p==null?"student":p)
w.j(0,r.gac(),new B.vd(r.gac(),p.toLowerCase(),n))}e=this.c.b
if(e!=null)for(e=e.ga2(),v=e.length,u=y.z,s=0;s<e.length;e.length===v||(0,A.a_)(e),++s){r=e[s]
m=r.I()
if(m.h(0,"deletedAt")!=null&&!w.aw(r.gac())){t=A.rY(j,j,x,u)
t.B(0,m)
t.j(0,"id",r.gac())
t.j(0,h,"plan")
p=m.h(0,g)
t.j(0,g,p==null?"Plan":p)
p=m.h(0,g)
t.j(0,"displayName",p==null?"Plan":p)
w.j(0,r.gac(),new B.vd(r.gac(),"plan",t))}}e=a0.b
if(e!=null)for(e=e.ga2(),v=e.length,u=y.f,t=y.z,s=0;s<e.length;e.length===v||(0,A.a_)(e),++s){r=e[s]
if(!w.aw(r.gac())){q=r.I()
if(u.b(q.h(0,i))){p=u.a(q.h(0,i)).fJ(0,x,t)
o=A.rY(j,j,x,t)
o.B(0,p)
o.B(0,q)
n=o}else n=q
p=n.h(0,h)
p=J.K(p==null?"student":p)
w.j(0,r.gac(),new B.vd(r.gac(),p.toLowerCase(),n))}}e=w.$ti.i("cK<2>")
l=A.Y(new A.cK(w,e),e.i("P.E"))
C.h.cI(l,new B.cqd())
f.a=null
e=this.a
x=e.w
if(x==="Students"){x=A.ab(l).i("au<1>")
k=A.Y(new A.au(l,new B.cqe(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Receipts & Payments"||x==="Receipts"||x==="Payments"){x=A.ab(l).i("au<1>")
k=A.Y(new A.au(l,new B.cqf(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Plans"){x=A.ab(l).i("au<1>")
k=A.Y(new A.au(l,new B.cqg(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Sections"){x=A.ab(l).i("au<1>")
k=A.Y(new A.au(l,new B.cqh(),x),x.i("P.E"))
f.a=k
x=k}else if(x==="Announcements"){x=A.ab(l).i("au<1>")
k=A.Y(new A.au(l,new B.cqi(),x),x.i("P.E"))
f.a=k
x=k}else{f.a=l
x=l}x=x.length
if(x===0){e=e.w
return new A.xT(C.ly,"No deleted "+(e==="All"?"items":e.toLowerCase())+" found!","Deleted items appear here for 30 days and can be restored anytime.",j,j,j)}return A.kd(A.lI(j,new B.cqj(f,e),x,C.hP,j,new B.cqk(),!1),new B.cql(e))},
$S:90}
B.cqd.prototype={
$2(d,e){var x,w,v,u="deletedAt",t=d.c.h(0,u),s=e.c.h(0,u)
if(t instanceof A.dX)x=A.eD(t.gbe())
else x=typeof t=="string"?A.dD(t):null
if(s instanceof A.dX)w=A.eD(s.gbe())
else w=typeof s=="string"?A.dD(s):null
v=x==null
if(v&&w==null)return 0
if(v)return 1
if(w==null)return-1
return w.b6(0,x)},
$S:z+1}
B.cqe.prototype={
$1(d){return d.b==="student"},
$S:z+0}
B.cqf.prototype={
$1(d){var x=d.b
return x==="receipt"||x==="payment"},
$S:z+0}
B.cqg.prototype={
$1(d){return d.b==="plan"},
$S:z+0}
B.cqh.prototype={
$1(d){return d.b==="section"},
$S:z+0}
B.cqi.prototype={
$1(d){return d.b==="announcement"},
$S:z+0}
B.cql.prototype={
$0(){var x=0,w=A.o(y.H),v=this
var $async$$0=A.k(function(d,e){if(d===1)return A.l(e,w)
for(;;)switch(x){case 0:v.a.v(new B.cqa())
x=2
return A.d(A.hb(C.p8,null,y.z),$async$$0)
case 2:return A.m(null,w)}})
return A.n($async$$0,w)},
$S:1}
B.cqa.prototype={
$0(){},
$S:0}
B.cqk.prototype={
$2(d,e){return C.bX},
$S:84}
B.cqj.prototype={
$2(a4,a5){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=null,e="displayName",d="paymentMethod",a0="name",a1=this.a.a[a5],a2=a1.c,a3=a1.b
switch(a3){case"receipt":x=a2.h(0,e)
if(x==null){w=a2.h(0,"receiptNumber")
x="Receipt #"+A.r(w==null?a1.a:w)}w=A.be(a2.h(0,"amount"))
w=w==null?f:C.l.R(w,0)
w=A.r(w==null?0:w)
v=a2.h(0,d)
u="Amount: \u20b9"+w+" \u2022 Paid via: "+A.r(v==null?"Cash":v)
t=C.d9
s=C.bi
break
case"payment":x=a2.h(0,e)
if(x==null){w=A.be(a2.h(0,"amount"))
w=w==null?f:C.l.R(w,0)
x="Payment: \u20b9"+A.r(w==null?0:w)}w=a2.h(0,d)
if(w==null)w=a2.h(0,"method")
u="Method: "+A.r(w==null?"Cash":w)
t=C.io
s=C.X
break
case"plan":x=a2.h(0,a0)
if(x==null)x="Plan"
w=A.r(a2.h(0,"price"))
v=A.r(a2.h(0,"duration"))
r=a2.h(0,"durationUnit")
u="Fee: \u20b9"+w+" \u2022 "+v+" "+A.r(r==null?"months":r)
t=C.rD
s=C.eB
break
case"section":x=a2.h(0,a0)
if(x==null)x="Section / Hall"
w=a2.h(0,"totalSeats")
u=A.r(w==null?"Configured":w)+" seats"
t=C.pz
s=C.c7
break
case"announcement":x=a2.h(0,"title")
if(x==null)x="Announcement"
u=a2.h(0,"message")
if(u==null)u=""
t=C.hu
s=C.eC
break
case"student":default:x=a2.h(0,a0)
if(x==null)x="Student"
q=a2.h(0,"phone")
if(q==null)q=""
p=a2.h(0,"seatId")
if(p==null)p=""
w=J.eB(q)?"Phone: "+A.r(q):""
u=w+(J.eB(p)?" \u2022 Seat: "+A.r(p):"")
t=C.ff
s=C.br
break}o=a2.h(0,"deletedAt")
n=""
m=30
if(o!=null){l=o instanceof A.dX?A.eD(o.gbe()):f
if(typeof o=="string")l=A.dD(o)
if(l!=null){n=A.aM("dd MMM yyyy",f).a9(l)
m=C.j.am(30-C.j.ae(new A.ae(Date.now(),0,!1).c9(l).a,864e8),0,30)}}w=A.cP(s.n(0.12),f,A.Z(t,s,f,f,22),f,f,f)
v=A.c(x,f,f,f,f,C.dC,f,f,f)
r=y.p
k=A.a([],r)
if(u.length!==0)k.push(A.c(u,f,f,f,f,C.E8,f,f,f))
k.push(C.dl)
j=s.n(0.15)
i=A.i(4)
i=A.a([A.w(f,A.c(a3.toUpperCase(),f,f,f,f,A.z(f,f,s,f,f,f,f,f,f,f,f,10,f,f,C.w,f,f,!0,f,f,f,f,f,f,f,f),f,f,f),C.n,f,f,new A.x(j,f,f,i,f,f,C.u),f,f,f,f,C.bK,f,f,f),C.E],r)
if(n.length!==0)i.push(A.c("Deleted: "+n,f,f,f,f,C.kT,f,f,f))
i.push(C.c5)
j=m<=5
h=j?C.no:C.fb
g=A.i(4)
i.push(A.w(f,A.c(""+m+" days left",f,f,f,f,A.z(f,f,j?C.ex:C.bn,f,f,f,f,f,f,f,f,10,f,f,C.w,f,f,!0,f,f,f,f,f,f,f,f),f,f,f),C.n,f,f,new A.x(h,f,f,g,f,f,C.u),f,f,f,f,C.bK,f,f,f))
k.push(A.t(i,C.k,C.f,C.i,0,f,f))
i=this.b
return A.bU(!1,f,f,f,!0,f,f,f,!0,f,f,w,f,f,f,f,f,!1,f,f,f,f,f,A.A(k,C.y,f,C.f,C.i,0,C.o),f,f,v,f,A.t(A.a([A.aK(f,f,f,C.XZ,f,f,new B.cqb(i,a1,a2),f,f,f,"Restore "+a3,f),A.aK(f,f,f,C.XH,f,f,new B.cqc(i,a1),f,f,f,"Delete Forever",f)],r),C.k,C.f,C.C,0,f,f),f)},
$S:85}
B.cqb.prototype={
$0(){return this.a.zO(this.b.a,this.c)},
$S:0}
B.cqc.prototype={
$0(){return this.a.H_(this.b.a)},
$S:0};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.vd,A.W)
x(B.GF,A.ou)
x(B.aJh,A.nI)
w(A.m4,[B.cq3,B.cq9,B.cq5,B.cqr,B.cqv,B.cqu,B.cqe,B.cqf,B.cqg,B.cqh,B.cqi])
w(A.os,[B.cq1,B.cq2,B.cq4,B.cq6,B.cq7,B.cqp,B.cqs,B.cqt,B.cqo,B.cql,B.cqa,B.cqb,B.cqc])
w(A.ot,[B.cq8,B.cqq,B.cqx,B.cqw,B.cqn,B.cqm,B.cqd,B.cqk,B.cqj])})()
A.vk(b.typeUniverse,JSON.parse('{"GF":{"ak":[],"u":[]},"aJh":{"ap":["GF"]}}'))
var y=(function rtii(){var x=A.az
return{s:x("a2<e>"),p:x("a2<u>"),j:x("Q<@>"),P:x("ag<e,@>"),f:x("ag<@,@>"),K:x("W"),C:x("dj<ag<e,@>>"),N:x("e"),v:x("vd"),q:x("q6"),y:x("a7"),z:x("@"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.cvr=new A.f("Recycle Bin",null,null,null,null,null,null,null,null,null,null)
D.UL=new A.le(C.co,C.a6,D.cvr,null)
D.aJR=new A.y(C.da,36,C.a7,null,null)
D.aRf=new A.y(C.jy,48,C.a7,null,null)
D.aTz=new A.y(C.A4,null,C.a7,null,null)
D.aQe=new A.y(C.da,null,C.bi,null,null)
D.czD=new A.f("Seat Already Occupied",null,null,null,null,null,null,null,null,null,null)
D.bMn=x([D.aQe,C.E,D.czD],y.p)
D.c9d=new A.bX(C.aa,C.f,C.i,C.k,null,C.o,null,0,D.bMn,null)
D.cGb=new A.f("Permanently deleted.",null,null,null,null,null,null,null,null,null,null)
D.cee=new A.bH(D.cGb,null,null,null,null,null,null,null,null,null,null,null,null,C.L,!1,null,null,null,C.z,null)
D.crw=new A.f("Recycle bin emptied.",null,null,null,null,null,null,null,null,null,null)
D.ceT=new A.bH(D.crw,null,null,null,null,null,null,null,null,null,null,null,null,C.L,!1,null,null,null,C.z,null)
D.csx=new A.f("Restore Without Seat",null,null,null,null,null,null,null,null,null,null)
D.cKF=new A.f("Delete Permanently",null,null,null,null,null,null,null,null,null,null)
D.cL6=new A.f("Empty All",null,C.jJ,null,null,null,null,null,null,null,null)})()};
(a=>{a["boxYNnTVclYH/xp/snL1StUw3tM="]=a.current})($__dart_deferred_initializers__);