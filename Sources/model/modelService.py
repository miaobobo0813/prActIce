import os
os.environ["HF_ENDPOINT"]="https://hf-mirror.com"

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import uvicorn

service = FastAPI(title="Model Adapter Service for prActIce")
service.add_middleware(
    CORSMiddleware, 
    allow_origins=['*'], 
    allow_credentials=True, 
    allow_headers=['*'], 
    allow_methods=['*']
)
MODELNAME = "Qwen/Qwen2.5-0.5B-Instruct"

tokenizerForQues = AutoTokenizer.from_pretrained(MODELNAME, trust_remote_code=True)
baseModelForQues = AutoModelForCausalLM.from_pretrained(MODELNAME, dtype="auto", trust_remote_code=True, device_map="auto")
modelForQues = PeftModel.from_pretrained(baseModelForQues, "./outputQues", device_map="auto")
modelForQues.eval()

# tokenizerForGrade = AutoTokenizer.from_pretrained(MODELNAME, trust_remote_code=True)
# baseModelForGrade = AutoModelForCausalLM.from_pretrained(MODELNAME, dtype="auto", trust_remote_code=True, device_map="auto")
# modelForGrade = PeftModel.from_pretrained(baseModelForGrade, "./outputGrade", device_map="auto")
# modelForGrade.eval()

@service.post("/ques")
async def quesAPI(grade: str, subject: str, unit: str, type: str):
    instruction = f"学科：{subject}，年级：{grade[1]}年级{'上册' if grade[0] == 'A' else '下册'}，单元：{unit}，题型：{type}"
    messages = [
        {"role": "system", "content": "你是一个出卷老师，请按照科目、单元、年级、题型出题。题型的类型有choose, fillBlank, answer，分别对应选择/判断、填空、实验探究/解答/综合"}, 
        {"role": "user", "content": instruction}
    ]
    text = tokenizerForQues.apply_chat_template(messages, tokenize=False, generation_prompt=True)
    modelInputs = tokenizerForQues([text], return_tensors="pt").to(modelForQues.device)
    generatedIDs = modelForQues.generate(
        **modelInputs, 
        max_new_tokens=512
    )
    generated_ids = [
        outputIDs[len(inputIDs):] for inputIDs, outputIDs in zip(modelInputs.input_ids, generatedIDs)
    ]
    return {"text": tokenizerForQues.batch_decode(generatedIDs, skip_spectial_tokens=True)[0]}

# @service.post("/grade")
# async def gradeAPI(ques: str, userAns: str):
#     instruction = f"问题：{ques}，学生回答；{userAns}"
#     messages = [
#         {"role": "system", "content": "你是一个批改作业的老师，请用\"true\"和\"false\"批改。"}, 
#         {"role": "user", "content": instruction}
#     ]
#     text = tokenizerForGrade.apply_chat_template(messages, tokenize=False, generation_prompt=True)
#     modelInputs = tokenizerForGrade([text], return_tensors="pt").to(modelForGrade.device)
#     generatedIDs = modelForGrade.generate(
#         **modelInputs, 
#         max_new_tokens=512
#     )
#     generated_ids = [
#         outputIDs[len(inputIDs):] for inputIDs, outputIDs in zip(modelInputs.input_ids, generatedIDs)
#     ]
#     return {"text": tokenizerForGrade.batch_decode(generatedIDs, skip_spectial_tokens=True)[0]}

if __name__ == "__main__":
    uvicorn.run(service, host="127.0.0.1", port=8000)