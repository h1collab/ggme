"""Two deterministic Loop-subdivision passes on verified WRAD CC0 subsets.

This is an explicitly modified derivative of wriks' source-authored mesh,
not a replacement hand. Preserve original skeleton, inverse binds, materials
and images; interpolate UVs across each original UV chart, skin weights across
welded geometry and recompute smooth normals. No runtime subdivision.
"""
import hashlib
import json
import math
import struct
from pathlib import Path

INPUT_SHA = {
    'b482a9044dd7de24ff7fc7e8b0d1a8cb9f2dccd437fbfffbce75f0cb9d7162d0': 1178,
    'ffaa7f460116541a127bb6bc3c24d028d6b89c6eae9911466bd8965a919eb09c': 589,
    '297e4459798e59c4cb4d2bc9386000141a65aa1b991a6990a564f52e5fb15261': 589,
}

def refine(path: Path) -> dict:
    data=path.read_bytes(); source_sha=hashlib.sha256(data).hexdigest()
    if source_sha not in INPUT_SHA: raise ValueError('Unverified WRAD subset for refinement')
    length=struct.unpack_from('<I',data,12)[0]
    g=json.loads(data[20:20+length]); offset=20+length
    n,kind=struct.unpack_from('<I4s',data,offset)
    if kind!=b'BIN\0':raise ValueError('Missing GLB buffer')
    raw=bytearray(data[offset+8:offset+8+n]); prim=g['meshes'][0]['primitives'][0]
    def read(index):
        a=g['accessors'][index];v=g['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        fmt,size={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
        start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',width*size)
        return [struct.unpack_from('<'+fmt*width,raw,start+i*stride) for i in range(a['count'])]
    attrs=prim['attributes']; positions=read(attrs['POSITION']);uv=read(attrs['TEXCOORD_0'])
    joints=read(attrs['JOINTS_0']);weights=read(attrs['WEIGHTS_0'])
    triangles=[x[0] for x in read(prim['indices'])]
    if len(triangles)//3!=INPUT_SHA[source_sha]:raise ValueError('Source subset triangle inventory changed')
    skin=[{int(j):float(w) for j,w in zip(js,ws) if w>0} for js,ws in zip(joints,weights)]
    max_discard=0.0
    for level in range(2):
        geo=[];geo_skin=[];weld={};mapping=[]
        for p,w in zip(positions,skin):
            key=tuple(round(x,6) for x in p)
            if key not in weld:weld[key]=len(geo);geo.append(p);geo_skin.append(w)
            idx=weld[key]
            if max((abs(w.get(j,0)-geo_skin[idx].get(j,0)) for j in set(w)|set(geo_skin[idx])),default=0)>.001:
                raise ValueError('Source coincident seam has inconsistent skin weights')
            mapping.append(idx)
        edges={};neighbors=[set() for _ in geo]
        faces=[]
        for i in range(0,len(triangles),3):
            a,b,c=[mapping[x] for x in triangles[i:i+3]]
            if len({a,b,c})!=3:raise ValueError('Degenerate source face')
            faces.append((a,b,c))
            for u,v,o in [(a,b,c),(b,c,a),(c,a,b)]:
                key=tuple(sorted((u,v)));edges.setdefault(key,[]).append(o)
                neighbors[u].add(v);neighbors[v].add(u)
        boundary=[set() for _ in geo]
        for (a,b),opposite in edges.items():
            if len(opposite)>2:raise ValueError('Nonmanifold source topology')
            if len(opposite)==1:boundary[a].add(b);boundary[b].add(a)
        def blend(stencil):
            p=tuple(sum(geo[i][d]*w for i,w in stencil) for d in range(3));skin_sum={}
            for i,w in stencil:
                for joint,value in sorted(geo_skin[i].items()):skin_sum[joint]=skin_sum.get(joint,0)+w*value
            ordered=sorted(skin_sum.items(),key=lambda kv:(-kv[1],kv[0]));retained=ordered[:4]
            discarded=sum(w for _,w in ordered[4:]);total=sum(w for _,w in retained)
            if discarded>.12 or total<=0:raise ValueError('Refined skin lost excessive influence')
            return p,{j:w/total for j,w in retained},discarded
        new_geo=[];new_skin=[]
        for i,p in enumerate(geo):
            if boundary[i]:
                if len(boundary[i])!=2:raise ValueError('Unexpected open source boundary')
                stencil=[(i,.75)]+[(j,.125) for j in sorted(boundary[i])]
            else:
                count=len(neighbors[i]);beta=3/16 if count==3 else 3/(8*count)
                stencil=[(i,1-count*beta)]+[(j,beta) for j in sorted(neighbors[i])]
            point,w,discarded=blend(stencil);new_geo.append(point);new_skin.append(w);max_discard=max(max_discard,discarded)
        odd={}
        for (a,b),opposite in sorted(edges.items()):
            stencil=[(a,.5),(b,.5)] if len(opposite)==1 else [(a,.375),(b,.375)]+[(j,.125) for j in sorted(opposite)]
            point,w,discarded=blend(stencil);odd[(a,b)]=len(new_geo);new_geo.append(point);new_skin.append(w);max_discard=max(max_discard,discarded)
        new_mapping=mapping[:];new_uv=uv[:];render_edges={}
        def midpoint(a,b):
            key=tuple(sorted((a,b)))
            if key not in render_edges:
                render_edges[key]=len(new_mapping)
                new_mapping.append(odd[tuple(sorted((mapping[a],mapping[b])))])
                new_uv.append(tuple((uv[a][d]+uv[b][d])*.5 for d in range(2)))
            return render_edges[key]
        new_tri=[]
        for i in range(0,len(triangles),3):
            a,b,c=triangles[i:i+3];ab,bc,ca=midpoint(a,b),midpoint(b,c),midpoint(c,a)
            new_tri.extend((a,ab,ca,ab,b,bc,ca,bc,c,ab,bc,ca))
        positions=[new_geo[i] for i in new_mapping];skin=[new_skin[i] for i in new_mapping];uv=new_uv;triangles=new_tri
    normals=[[0.,0.,0.] for _ in new_geo]
    for i in range(0,len(triangles),3):
        ids=[new_mapping[j] for j in triangles[i:i+3]];a,b,c=[new_geo[j] for j in ids]
        u=[b[d]-a[d] for d in range(3)];v=[c[d]-a[d] for d in range(3)]
        normal=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
        for idx in ids:
            for d in range(3):normals[idx][d]+=normal[d]
    for normal in normals:
        length=math.sqrt(sum(x*x for x in normal))
        if length<1e-10:raise ValueError('Invalid derivative normal')
        for d in range(3):normal[d]/=length
    normal_stream=[normals[i] for i in new_mapping]
    joint_stream=[];weight_stream=[]
    for w in skin:
        values=sorted(w.items(),key=lambda kv:(-kv[1],kv[0]))
        joint_stream.append([j for j,v in values]+[0]*(4-len(values)))
        weight_stream.append([v for j,v in values]+[0.]*(4-len(values)))
    def write(values,kind,fmt,component,target=34962,bounds=False):
        while len(raw)%4:raw.append(0)
        start=len(raw)
        for row in values:raw.extend(struct.pack('<'+fmt*len(row),*row))
        g['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(raw)-start,'target':target})
        a={'bufferView':len(g['bufferViews'])-1,'componentType':component,'count':len(values),'type':kind}
        if bounds:
            a['min']=[min(row[d] for row in values) for d in range(len(values[0]))]
            a['max']=[max(row[d] for row in values) for d in range(len(values[0]))]
        g['accessors'].append(a);return len(g['accessors'])-1
    prim['attributes']={'POSITION':write(positions,'VEC3','f',5126,bounds=True),'NORMAL':write(normal_stream,'VEC3','f',5126),'TEXCOORD_0':write(uv,'VEC2','f',5126),'JOINTS_0':write(joint_stream,'VEC4','H',5123),'WEIGHTS_0':write(weight_stream,'VEC4','f',5126)}
    prim['indices']=write([(i,) for i in triangles],'SCALAR','H' if max(triangles)<65536 else 'I',5123 if max(triangles)<65536 else 5125,target=34963,bounds=True)
    while len(raw)%4:raw.append(0)
    g['buffers'][0]['byteLength']=len(raw)
    info={'source_subset_sha256':source_sha,'source_triangles':INPUT_SHA[source_sha],'derived_triangles':len(triangles)//3,'subdivision_levels':2,'max_discarded_skin_weight':max_discard,'vertices':len(positions)}
    assert info['derived_triangles']==info['source_triangles']*16
    assert all(abs(sum(w)-1)<1e-6 for w in weight_stream)
    assert all(math.isfinite(x) for p in positions for x in p)
    g.setdefault('asset',{}).setdefault('extras',{})['wrad_cc0_derivative']=info
    js=json.dumps(g,ensure_ascii=True,separators=(',',':')).encode();js+=b' '*(-len(js)%4)
    result=b'glTF'+struct.pack('<II',2,28+len(js)+len(raw))+struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(raw),b'BIN\0')+raw
    path.write_bytes(result);info['sha256']=hashlib.sha256(result).hexdigest();return info

if __name__=='__main__':
    import sys
    print(json.dumps(refine(Path(sys.argv[1])),sort_keys=True))
