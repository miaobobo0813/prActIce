# type: ignore

import os
import sys
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

quantization_config = BitsAndBytesConfig(load_in_4bit=True)

if len(sys.argv) > 1:
    PathToModel = sys.argv[1]
else:
    PathToModel = "Qwen/Qwen3.5-2B"
tokenizer = AutoTokenizer.from_pretrained(PathToModel)
model = AutoModelForCausalLM.from_pretrained(PathToModel, device_map="cpu", dtype="auto", low_cpu_mem_usage=True, quantization_config=quantization_config)

class QuestionRequest(BaseModel):
    grade: str
    subject: str
    unit: str
    type: str
    scope: str


class GradeRequest(BaseModel):
    ques: str
    userAns: str

service = FastAPI()

@service.post("/ques")
def quesService(unit: QuestionRequest):
    messages = [
        {"role": "system", "content": "你是一个出卷老师，请按照科目、单元、年级、题型、范围出题。choose代表选择/判断, fillBlank代表填空, answer代表实验探究/解答/综合。数学、科学使用浙教版，英语使用外研版，剩余科目使用人教版。只需出一题即可。不需要给出答案。",},
        {"role": "user", "content": f"科目:{unit.subject}，年级:{unit.grade[1]+unit.grade[0]}，单元:{unit.unit}，题型:{unit.type}，范围:{unit.scope}"},
    ]
    tokenized_chat = tokenizer.apply_chat_template(messages, tokenize=True, add_generation_prompt=True, return_tensors="pt")
    outputs = model.generate(tokenized_chat, max_new_tokens=1024) 
    output = tokenizer.decode(outputs[0])
    if "<|assistant|>" in output:
        return {"text": output.split("<|assistant|>", 1)[1]}
    return {"text": output}

@service.post("/grade")
def gradeService(ques: GradeRequest):
    messages = [
        {"role": "system", "content": "你是一个批改作业的老师。请根据题目类型进行评分：选择题和填空题每空1分，若回答正确则输出 1/1；若回答错误则输出 0/1；若题目包含多个空，请按空数给出如 2/3 或 1/3 的分数。请只输出最终评分结果，不要解释。",},
        {"role": "user", "content": f"题目:{ques.ques}，学生答案:{ques.userAns}"},
    ]
    tokenized_chat = tokenizer.apply_chat_template(messages, tokenize=True, add_generation_prompt=True, return_tensors="pt")
    outputs = model.generate(tokenized_chat, max_new_tokens=1024) 
    output = tokenizer.decode(outputs[0])
    if "<|assistant|>" in output:
        return {"text": output.split("<|assistant|>", 1)[1]}
    return {"text": output}

@service.get("/test")
def testService():
    return {"text": True}

if __name__ == "__main__":
    uvicorn.run(service, host="127.0.0.1", port=8000)