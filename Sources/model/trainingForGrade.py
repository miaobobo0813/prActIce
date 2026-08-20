# trainingForGrade.py

import os
os.environ["HF_ENDPOINT"]="https://hf-mirror.com"

import json
from transformers import AutoModelForCausalLM, AutoTokenizer, Trainer, TrainingArguments, DataCollatorForLanguageModeling
from peft import LoraConfig, TaskType
from datasets import Dataset

if __name__ == "__main__":
    MODELNAME = "Qwen/Qwen2.5-0.5B-Instruct"
    tokenizer = AutoTokenizer.from_pretrained(MODELNAME, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    model = AutoModelForCausalLM.from_pretrained(MODELNAME, trust_remote_code=True, dtype="auto", device_map="auto")

    def loadJson(filePath):
        with open(filePath, 'r', encoding='utf-8') as f:
            return json.load(f)

    dataOfGrade = loadJson("./Sources/model/trainGradeData.json")
    formattedDataOfGrade = []
    for data in dataOfGrade:
        output = str(data.get("output", "0/1"))
        messages = [
            {"role": "system", "content": "你是一个批改作业的老师。请根据题目类型进行评分：选择题和填空题每空1分，若回答正确则输出 1/1；若回答错误则输出 0/1；若题目包含多个空，请按空数给出如 2/3 或 1/3 的分数。请只输出最终评分结果，不要解释。"}, 
            {"role": "user", "content": f"问题：{data['question']}，学生回答；{data['userAnswer']}"}, 
            {"role": "assistant", "content": output}
        ]
        fullText = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=False)
        inputID = tokenizer(fullText, truncation=True, max_length=512)["input_ids"]
        promptText = tokenizer.apply_chat_template(messages[:-1], tokenize=False, add_generation_prompt=True)
        promptIDs = tokenizer(promptText, add_special_tokens=False)["input_ids"]
        labels = inputID.copy()
        promptLen = len(promptIDs)
        labels[:promptLen] = [-100]*promptLen
        formattedDataOfGrade.append({"input_ids": inputID, "labels": labels})
    datasetOfGrade = Dataset.from_list(formattedDataOfGrade)
    peftConfig = LoraConfig(
        task_type=TaskType.CAUSAL_LM, 
        inference_mode=False, 
        r=8, 
        lora_alpha=32, 
        lora_dropout=0.1
    )
    model.add_adapter(peftConfig, adapter_name="grade")

    model.set_adapter("grade")
    trainArgsForGrade = TrainingArguments(
        output_dir="./Sources/model/outputGrade", 
        num_train_epochs=10, 
        per_device_train_batch_size=1, 
        gradient_accumulation_steps=4, 
        learning_rate=1e-4, 
        fp16=False, 
        optim="adamw_torch", 
        logging_steps=1, 
        save_strategy="epoch", 
        dataloader_pin_memory=False, 
        dataloader_num_workers=0, 
        disable_tqdm=False
    )
    trainerForGrade = Trainer(
        model=model, 
        args=trainArgsForGrade, 
        train_dataset=datasetOfGrade, 
        data_collator=DataCollatorForLanguageModeling(tokenizer, mlm=False)
    )
    trainerForGrade.train()
    model.save_pretrained("./Sources/model/outputGrade")