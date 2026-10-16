from pathlib import Path
import json,math,copy
ref=Path(__file__).resolve().parent
samples=[([float(x)for x in row['values']],[1.,0.]if row['label']=='good'else[0.,1.])
         for row in json.loads((ref/'samples.json').read_text())]
def reference(epochs):
    fields=(ref/f'epochs-{epochs}.output').read_text().split();pos=0;layers=[]
    for index in range(3):
        assert fields[pos:pos+2]==['layer',str(index)];m,n=map(int,fields[pos+2:pos+4]);pos+=4
        values=list(map(float,fields[pos:pos+m*n]));pos+=m*n
        bias=list(map(float,fields[pos:pos+m]));pos+=m
        layers.append({'w':[values[i*n:(i+1)*n]for i in range(m)],'b':bias})
    assert fields[pos:pos+2]==['predictions','351'];pos+=2
    values=list(map(float,fields[pos:pos+702]));pos+=702
    assert fields[pos]=='error'and pos+2==len(fields)
    return layers,[values[2*i:2*i+2]for i in range(351)],float(fields[pos+1])
def dot(x,y):
    total=0.0
    for a,b in zip(x,y):total+=a*b
    return total
def forward(layers,input):
    activations=[input]
    for index,layer in enumerate(layers):
        values=[dot(row,activations[-1])+bias for row,bias in zip(layer['w'],layer['b'])]
        if index<2:values=[math.tanh(x)for x in values]
        else:
            exp=[math.exp(x)for x in values];total=0.
            for x in exp:total+=x
            scale=1./total;values=[scale*x for x in exp]
        activations.append(values)
    return activations
def train(layers,input,target):
    activations=forward(layers,input)
    # Structured derivatives avoid constructing the source's dense Jacobians.
    deltas=[None]*3;deltas[2]=[y-t for y,t in zip(activations[-1],target)]
    for level in [1,0]:
        upper=layers[level+1]['w'];updelta=deltas[level+1]
        deltas[level]=[(1.-y*y)*sum(upper[j][i]*updelta[j]for j in range(len(updelta)))
                       for i,y in enumerate(activations[level+1])]
    for level,layer in enumerate(layers):
        for i,row in enumerate(layer['w']):
            for j in range(len(row)):row[j]+=(-.01)*(deltas[level][i]*activations[level][j])
            layer['b'][i]+=(-.01)*deltas[level][i]
initial,_,_=reference(0);records=[]
for epochs in [1,20]:
    layers=copy.deepcopy(initial)
    for _ in range(epochs):
        for input,target in samples:train(layers,input,target)
    expected,predictions,error=reference(epochs)
    parameter_error=max(abs(a-b)for actual,wanted in zip(layers,expected)
      for ar,wr in zip(actual['w']+[actual['b']],wanted['w']+[wanted['b']])for a,b in zip(ar,wr))
    outputs=[forward(layers,input)[-1]for input,_ in samples]
    prediction_error=max(abs(a-b)for actual,wanted in zip(outputs,predictions)for a,b in zip(actual,wanted))
    actual_error=0.0
    for output,(_,target)in zip(outputs,samples):
        sample_error=0.0
        for t,y in zip(target,output):sample_error+=t*math.log(y)
        actual_error+=-sample_error
    assert parameter_error<2e-8 and prediction_error<2e-8 and abs(actual_error-error)<1e-7
    records.append({'epochs':epochs,'parameter_max_error':parameter_error,'prediction_max_error':prediction_error,'total_error_difference':abs(actual_error-error),'method':'structured derivatives and simplified softmax/cross-entropy delta, independent of dense source Jacobians'})
    print('PASS independent training',records[-1],flush=True)
(ref/'independent.json').write_text(json.dumps(records,indent=2)+'\n')
