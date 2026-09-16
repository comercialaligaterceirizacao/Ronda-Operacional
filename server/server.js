const http=require('http'),fs=require('fs'),path=require('path');
const DB=path.join(__dirname,'data.json');
if(!fs.existsSync(DB))fs.writeFileSync(DB,JSON.stringify({seq:124,usuarios:[{usuario:'supervisor',senha:'1234',nome:'Supervisor',perfil:'supervisor'},{usuario:'almoxarifado',senha:'1234',nome:'Almoxarifado',perfil:'almoxarifado'}],requisicoes:[]},null,2));
const read=()=>JSON.parse(fs.readFileSync(DB));const write=x=>fs.writeFileSync(DB,JSON.stringify(x,null,2));
const body=req=>new Promise((res,rej)=>{let b='';req.on('data',x=>b+=x);req.on('end',()=>{try{res(b?JSON.parse(b):{})}catch(e){rej(e)}})});
const send=(r,code,x)=>{r.writeHead(code,{'Content-Type':'application/json','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'Content-Type'});r.end(JSON.stringify(x));};
const server=http.createServer(async(req,res)=>{if(req.method==='OPTIONS'){res.writeHead(204,{'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'Content-Type','Access-Control-Allow-Methods':'GET,POST,PATCH,OPTIONS'});return res.end();}try{const db=read(),u=new URL(req.url,'http://localhost');
 if(req.method==='POST'&&u.pathname==='/api/login'){const x=await body(req),a=db.usuarios.find(v=>v.usuario===x.usuario&&v.senha===x.senha);return a?send(res,200,a):send(res,401,{erro:'Usuário ou senha inválidos'});}
 if(req.method==='GET'&&u.pathname==='/api/requisicoes'){const user=u.searchParams.get('usuario');return send(res,200,db.requisicoes.filter(x=>x.usuario===user||user==='almoxarifado').sort((a,b)=>b.numero-a.numero));}
 if(req.method==='POST'&&u.pathname==='/api/requisicoes'){const x=await body(req),id=++db.seq,r={...x,id:String(id),numero:String(id).padStart(6,'0'),status:'Pendente',criadaEm:new Date().toISOString()};db.requisicoes.push(r);write(db);return send(res,201,r);}
 const m=u.pathname.match(/^\/api\/requisicoes\/(\d+)(\/entrega)?$/);if(m&&req.method==='PATCH'){const r=db.requisicoes.find(x=>x.id===m[1]);if(!r)return send(res,404,{erro:'Não encontrada'});const x=await body(req);if(m[2]){r.status='Entregue';r.entrega={...x,data:new Date().toISOString()};}else if(x.status)r.status=x.status;write(db);return send(res,200,r);}
 if(req.method==='GET'&&u.pathname==='/api/health')return send(res,200,{ok:true});send(res,404,{erro:'Rota não encontrada'});
}catch(e){send(res,500,{erro:e.message});}});server.listen(3000,'0.0.0.0',()=>console.log('A Liga Almoxarifado API: porta 3000'));
